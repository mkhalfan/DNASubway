package DNALC::Pipeline::Process::Blast;

use base q(DNALC::Pipeline::Process);
use IO::File ();

use Data::Dumper;
use strict;

{
	sub new {
		my ($class, $project_dir, $prog, $clade) = @_;

		$prog ||= 'blastn';
		my $self = __PACKAGE__->SUPER::new(uc($prog), $project_dir);
		return unless $self;

		if ($prog =~ /_user$/i) {
			$ENV{BLASTDB} = $project_dir . '/evidence';
			my $db = 'evid_prot';
			if ($prog eq 'blastn_user') {
				$db = 'evid_nt';
			}
			push @{$self->{work_options}}, ('-d', $db, '-i');
		}
		else {
			$ENV{BLASTDB} = $self->{conf}{blastdb};

			my $species_map = $self->{conf}->{species_map};
			if (defined $species_map && %$species_map) {
				unless ($clade && $clade =~ /^(?:a|f|♞|h|f|i|w|x)$/) {
					$clade = 'default';
				}
				$self->{clade} = $clade;
				if (defined $species_map->{$clade}) {
					my $db =  $species_map->{$clade};
					push @{ $self->{work_options} }, ('-d', $db, '-i');
				}
			}
		}

		$ENV{BLASTMAT}=$self->{conf}{blastmat};

		return $self;
	}

	sub get_gff3_file {
		my ($self, $dont_parse) = @_;

		my $dir = $self->{work_dir};
		my $gff_file = $dir . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file || $dont_parse);


		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR $self->{type} . ": output file is missing.", $/;
			return;
		}
		closedir DIR;

		my $file_to_parse = "$dir/$f[0]";
		my @opts = ($self->{conf}{parser_program});
		push @opts, @{ $self->{conf}{parser_opt} };
		push @opts, ("-i", $file_to_parse, "-o", $gff_file);
		my $cmd=join ' ', @opts;
		print STDERR  "PARSER = ", $cmd, $/;
		#system($cmd);
		system(@opts);

		#end parse file

		return $gff_file if (-e $gff_file);

	}


}

1;

