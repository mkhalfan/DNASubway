package DNALC::Pipeline::Process::Blast;

use base q(DNALC::Pipeline::Process);
use IO::File ();
use Bio::Tools::Fgenesh ();

use Data::Dumper;
use strict;

{
	sub new {
		my ($class, $project_dir, $prog) = @_;

		$prog ||= 'blastn';
		my $self = __PACKAGE__->SUPER::new(uc($prog), $project_dir);
		$ENV{BLASTDB}=$self->{conf}{blastdb};
		$ENV{BLASTMAT}=$self->{conf}{blastmat};
		$self->{prog} = $prog;

		return $self;
	}

	sub get_gff3_file {
		my ($self) = @_;

		my $dir = $self->{work_dir};
		my $gff_file = $dir . '/' . $self->{conf}->{gff3_file};
		return $gff_file if (-e $gff_file);


		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "BLAST: output file is missing.", $/;
			return;
		}
		closedir DIR;

		my $file_to_parse = "$dir/$f[0]";
		my @opts = ($self->{conf}{parser_program});
		push @opts, @{ $self->{conf}{parser_opt} };
		push @opts, ("-i", $file_to_parse, "-o", $gff_file);
		my $cmd=join ' ', @opts;
		system($cmd);

		#end parse file

		return $gff_file if (-e $gff_file);

	}


}

1;

