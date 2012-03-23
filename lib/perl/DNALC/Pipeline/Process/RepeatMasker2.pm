package DNALC::Pipeline::Process::RepeatMasker2;

use File::Path;
use base q(DNALC::Pipeline::Process);

{

	sub new {
		my ($class, $project_dir, $clade) = @_;

		my $self = __PACKAGE__->SUPER::new('REPEAT_MASKER2', $project_dir);

		my $species_map = $self->{conf}->{species_map};
		if (defined $species_map && %$species_map) {
			unless ($clade && $clade =~ /^(?:m|d|h|a|f)$/) {
				$clade = 'default';
			}
			$self->{clade} = $clade;
			if (defined $species_map->{$clade}) {
				my @species = 'ARRAY' eq ref $species_map->{$clade} ? @{$species_map->{$clade}} : ($species_map->{$clade});
				unshift @{ $self->{work_options} }, @species;
			}
		}

		return $self;
	}

	sub _setup {
		my ($self, $project_dir) = @_;

		$self->SUPER::_setup($project_dir);

		# extra work
		if ($self->{conf}->{output_dir}) {
			my $out_dir = $self->{work_dir} . '/' . $self->{conf}->{output_dir};
			unless (-e $out_dir) {
				mkpath($out_dir);
			}
			if (defined $self->{conf}->{option_output_dir}) {
				my $opt_dir = $self->{conf}->{option_output_dir};
				if ($self->{conf}->{option_glue}) {
					push @{$self->{work_options}}, 
						$opt_dir . $self->{conf}->{option_glue} . $out_dir;
				}
				else {
					push @{$self->{work_options}}, (
							$opt_dir, $out_dir
						);
				}
			}
		}
	}
}

1;
