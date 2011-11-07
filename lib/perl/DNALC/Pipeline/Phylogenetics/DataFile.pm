package DNALC::Pipeline::Phylogenetics::DataFile;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use List::Util qw/max/;
use Bio::Trace::ABIF ();
use DNALC::Pipeline::Phylogenetics::DataSequence();

__PACKAGE__->table('phy_data_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_name file_path file_type has_low_q created/);
__PACKAGE__->sequence('phy_data_file_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

# retursn the DataSequence of this file
sub seq_object {
	my ($self) = @_;

	my ($seq) = DNALC::Pipeline::Phylogenetics::DataSequence->search(file_id => $self, project_id => $self->project_id);
	return $seq;
}

# returns the sequence(s) from the file
sub seq {
	my ($self) = @_;
	
	my $seq = '';
	return $seq unless ref($self) eq __PACKAGE__;

	if (-f $self->file_path) {
		if ($self->file_type =~ /^fasta$/i) {
			open FILE, $self->file_path or do {
					print STDERR "Can't open file: ", $self->file_path, $/;
					return '';
				};
			while (my $line = <FILE>) {
				$seq .= $line;
			}
			close FILE;
		}
		elsif ($self->file_type =~ /^trace$/i) {
			my $ab = Bio::Trace::ABIF->new;
			if ($ab->open_abif($self->file_path)) {
				$seq = $ab->sequence;
				$ab->close_abif;
			}
		}
	}
	$seq;
}

sub trace {
	my ($self) = @_;
	my $trace = ();
	return unless ref($self) eq __PACKAGE__ || $self->file_type !~ /^trace$/i;

	my $max = 0;
	my $ab = Bio::Trace::ABIF->new;

	if ($ab->open_abif($self->file_path)) {

		my @base_locations = $ab->base_locations();
		my $last_base_pos = $base_locations[$#base_locations];

		my $max = 0;
		for (qw(A G T C)) {
			my @t = $ab->trace($_);
			@t = splice @t, 0, $last_base_pos;
			$trace->{$_} = \@t;
			my $local_max = max(@t);
			$max = $local_max > $max ? $local_max : $max;
		}
		$ab->close_abif;
		for (keys %$trace) {
			$trace->{$_} = [ map { sprintf("%d", 100 * $_/$max) } @{$trace->{$_}}];
		}
	}
	$trace;
}

sub quality_values {
	my ($self) = @_;
	my @q = ();
	return unless ref($self) eq __PACKAGE__ || $self->file_type !~ /^trace$/i;
	
	my $ab = Bio::Trace::ABIF->new;
	if ($ab->open_abif($self->file_path)) {
		@q = $ab->quality_values;
		$ab->close_abif;
	}
	wantarray ? @q : \@q;
}


sub base_locations {
	my ($self) = @_;
	my @bl = ();
	return unless ref($self) eq __PACKAGE__ || $self->file_type !~ /^trace$/i;
	
	my $ab = Bio::Trace::ABIF->new;
	if ($ab->open_abif($self->file_path)) {
		@bl = $ab->base_locations;
		$ab->close_abif;
	}
	wantarray ? @bl : \@bl;
}

1;
