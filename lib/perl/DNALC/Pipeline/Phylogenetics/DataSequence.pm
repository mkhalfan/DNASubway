package DNALC::Pipeline::Phylogenetics::DataSequence;

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();
use POSIX qw/strftime/;
use List::Util qw/sum/;
#use Data::Dumper;

__PACKAGE__->table('phy_data_sequence');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_id display_id/);
__PACKAGE__->columns(Other => qw/seq created/);
__PACKAGE__->columns(TEMP => qw/source_name/);
__PACKAGE__->sequence('phy_data_sequence_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

__PACKAGE__->might_have(trimming => 'DNALC::Pipeline::Phylogenetics::DataSequenceTrim' => qw/left_trim right_trim start_pos end_pos/);

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


# The Trimming Function. Takes the sequence to be trimmed
# and optionally the window length and "N" Threshold
sub trim {
	my ($self, $window_length, $threshold) = @_;

	my ($file) = DNALC::Pipeline::Phylogenetics::DataFile->search(id => $self->file_id);
	my @quality_values = $file ? $file->quality_values : ();

	my $sequence = $self->seq;
	
	my $forward_total = _trim_sequence_string($sequence);
	my $reverse_total = _trim_sequence_string(scalar reverse $sequence);

	my ($qscore_trim_forward, $qscore_trim_reverse) = (0, 0);

	if (@quality_values) {
		# remove the appropriate numbers of qvalues
		splice(@quality_values, @quality_values - $reverse_total, $reverse_total) if $reverse_total;
		splice(@quality_values, 0, $forward_total) if $forward_total;

		# do the second trimming
		$qscore_trim_forward = _trim_quality_scores(\@quality_values);
		$qscore_trim_reverse = _trim_quality_scores([reverse @quality_values]);
	}

	#print STDERR "[", $self->project_id, "] forward_total: $forward_total, reverse_total: $reverse_total,\n\t",
	#		"qscore_trim_forward: $qscore_trim_forward, qscore_trim_reverse: $qscore_trim_reverse\n";

	$forward_total += $qscore_trim_forward;
	$reverse_total += $qscore_trim_reverse;

	my $trimmed_seq_length = length($sequence) - $reverse_total - $forward_total;
	my $trimmed_sequence = substr($sequence, $forward_total, $trimmed_seq_length);
	
	
	# Update The Database
	$self->left_trim(substr ($sequence, 0, $forward_total));
	$self->right_trim(substr ($sequence, (length $sequence) - $reverse_total, $reverse_total));
	$self->start_pos($forward_total);
	$self->end_pos(length($sequence) - $reverse_total);
	$self->seq($trimmed_sequence);
	return $self->update;
}

sub _trim_quality_scores {
    my ($quality_scores, $window_size, $threshold) = @_;

    my @quality_scores = @$quality_scores;

    $window_size ||= 18;
    $threshold ||= 22;

    my $trim = 0;

    for (my $i = 0; $i <= $#quality_scores; $i++) {
        my $sum = sum(@quality_scores[ $i .. ($i + $window_size-1) % $#quality_scores ]);
		$sum ||= 0;
        
        my $avg = $sum/$window_size;
        
        if ($avg < $threshold) { $trim += 1; }
        else { return $trim; }
    }
    return $trim;
}



sub _trim_sequence_string {
	my ($seq, $window_length, $threshold) = @_;

	$window_length ||= 12;
	$threshold ||= 2;
	my $total = 0;

	for (my $i = 0; $i <= length $seq; $i++) {
		my $window = substr($seq, $i, $window_length);
		my $cnt = () = $window =~ /N/g;
        if (index($window, "N") == 0 || $cnt >= $threshold) {
			$total++;
		}
		else {
			last;
		}
	}
	return $total;
	
}

__PACKAGE__->set_sql(non_paired_sequences =>q {
 	SELECT s.id, ds.name as source_name
    FROM phy_data_sequence AS s
    LEFT JOIN phy_pair_sequence ps ON s.id = ps.seq_id
    LEFT JOIN phy_data_source ds ON s.source_id = ds.id
    WHERE s.project_id = ?
    AND ps.pair_id IS NULL
});

__PACKAGE__->set_sql(trace_sequences =>q {
	SELECT s.id
	FROM phy_data_sequence AS s
	LEFT JOIN phy_data_source ds ON s.source_id = ds.id
	LEFT JOIN phy_data_file f ON s.file_id = f.id
	WHERE s.project_id = ?
	AND f.file_type = 'trace'
});

__PACKAGE__->set_sql(initial_non_trace_sequences =>q {
	SELECT s.id
	FROM phy_data_sequence AS s
	LEFT JOIN phy_data_source ds ON s.source_id = ds.id
	LEFT JOIN phy_data_file f ON s.file_id = f.id
	WHERE s.project_id = ?
	AND ds.name = 'init'
	AND f.file_type != 'trace'
});


__PACKAGE__->set_sql(initial_non_paired_sequences =>q {
	SELECT s.id
	FROM phy_data_sequence AS s
		LEFT JOIN phy_data_source ds ON s.source_id = ds.id
		LEFT JOIN phy_pair_sequence ps ON s.id = ps.seq_id
	WHERE s.project_id = ?
		AND ds.name = 'init'
		AND ps.pair_id IS NULL

});

sub undo_trimming {
	my ($class, $pid) = @_;

	# XXX FIXME
	# there may be a problem with the fasta/text based sequences in that we can't really untrim them..

	$class->db_Main->do(qq{
		DELETE from phy_trim WHERE id IN 
		(SELECT t.id
			FROM phy_trim t
			JOIN phy_data_sequence AS s ON t.id = s.id
			JOIN phy_data_source ds ON s.source_id = ds.id
			WHERE s.project_id = $pid
			AND ds.name = 'init'
		)
	});
}

1;
