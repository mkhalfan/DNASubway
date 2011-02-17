package DNALC::Pipeline::Phylogenetics::DataSequence;

#use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();
use POSIX qw/strftime/;
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

	my $sequence = $self->seq;
	
	my $forward_total = _trim_sequence_string($sequence);
	my $reverse_total = _trim_sequence_string(scalar reverse $sequence);
	my $trimmed_seq_length = (length $sequence) - $reverse_total - $forward_total;
	my $trimmed_sequence = substr($sequence, $forward_total, $trimmed_seq_length);
	
	
	# Update The Database
	$self->left_trim(substr ($sequence, 0, $forward_total));
	$self->right_trim(substr ($sequence, (length $sequence) - $reverse_total, $reverse_total));
	$self->start_pos($forward_total);
	$self->end_pos((length $sequence) - $reverse_total);
	$self->seq($trimmed_sequence);
	return $self->update;
}

sub _trim_sequence_string {
	my ($seq, $window_length, $threshold) = @_;

	$window_length ||= 12;
	$threshold ||= 2;
	my $total = 0;

	for (my $i = 0; $i <= length $seq; $i++) {
		my $window = substr($seq, $i, $window_length);
		my $cnt = () = $window =~ /N/g;
		if (index($window, "N") == 0){
			$total++;
		}
		elsif ($cnt >= $threshold){
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


1;
