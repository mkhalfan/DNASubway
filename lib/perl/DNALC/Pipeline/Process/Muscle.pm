package DNALC::Pipeline::Process::Muscle;

use base q(DNALC::Pipeline::Process);
use File::Spec ();
use Bio::AlignIO ();
use File::Basename;

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

	sub do_postprocessing {
		my ($self, $m_output) = @_;
		print STDERR "got here!";

		if (defined $self->{conf}->{post_processing_cmd} && -x $self->{conf}->{post_processing_cmd}) {
			my $html_output = my $trimmed_output = $m_output;

			$trimmed_output =~ s/\.fasta$/_trimmed.fasta/;
			$html_output =~ s/\.fasta$/.html/;

			print STDERR  "** new file: ", $trimmed_output, $/;
			print STDERR  "** new file: ", $html_output, $/;

			my @args = (
					'-i', $m_output,      # -i input file, muscle output
					'-h', $html_output,   # -h the html output file
					'-o', $trimmed_output # -o trimmed alignment, output
				);
			if (system($self->{conf}->{post_processing_cmd}, @args) == 0) {
				print STDERR  'postprocessing exit status = ', $?, $/;
				return {html_output => $html_output, trimmed_output => $trimmed_output};
			}
		}
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

		my $trimmed_inputfilename = $inputfilename;
		$trimmed_inputfilename =~ s/\.fasta$/_trimmed.fasta/;
		if (-f $trimmed_inputfilename) {
			$inputfilename = $trimmed_inputfilename;
		}

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
