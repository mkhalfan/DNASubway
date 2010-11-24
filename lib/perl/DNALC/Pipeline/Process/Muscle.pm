package DNALC::Pipeline::Process::Muscle;

use base q(DNALC::Pipeline::Process);
use File::Spec ();
use Bio::AlignIO ();

{
	sub new {
		my ($class, $project_dir) = @_;

		my $self = __PACKAGE__->SUPER::new('MUSCLE', $project_dir);

		for (keys %{$self->{conf}->{option_output_files}}) {
			unshift @{$self->{work_options}}, 
				$_, $self->{work_dir} . '/'. $self->{conf}->{option_output_files}->{$_}
		}

		return $self;
	}

	sub get_output {
		my ($self, $format) = @_;
		$format ||= 'fasta';

		return unless $self->{exit_status} == 0;
	
		my $out_file;
		my ($out_type) = grep (/$format/i, keys %{$self->{conf}->{option_output_files}});
		if ($out_type) {
			$out_file = File::Spec->catfile($self->{work_dir}, $self->{conf}->{option_output_files}->{$out_type});
		}
		return $out_file if -e $out_file;
	}

	sub convert_fasta_to_phylip {
		my ($self) = @_;

		my $inputfilename = $self->get_output('fasta');
		my $outputfilename = $self->get_output('phyi');

		return unless -f $inputfilename;

		my $in  = Bio::AlignIO->new(-file   => $inputfilename ,
								 -format => 'fasta');
		my $out = Bio::AlignIO->new(-file   => "> $outputfilename" ,
								 -format => 'phylip',
								 -idlength => $self->{conf}->{phylip_id_length} || 10,
							 );

		while ( my $aln = $in->next_aln() ) {
			$out->write_aln($aln);
		}

		return $outputfilename if -f $outputfilename;
	}
}

1;
