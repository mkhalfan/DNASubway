package DNALC::Pipeline::Process::Augustus;

use base q(DNALC::Pipeline::Process);
use IO::File ();

use strict;

{
	sub new {
		my ($class, $project_dir, $clade) = @_;

		my $self = __PACKAGE__->SUPER::new('AUGUSTUS', $project_dir);

		my $species_map = $self->{conf}->{species_map};
		if (defined $species_map && %$species_map) {
			unless ($clade && $clade =~ /^(?:m|d|h|a|♞|f|i|w|x)$/) {
				$clade = 'default';
			}
			$self->{clade} = $clade;
			if (defined $species_map->{$clade}) {
				unshift @{ $self->{work_options} }, $species_map->{$clade};
			}
		}

		return $self;
	}

	sub get_gff3_file {
		my ($self, $dont_parse) = @_;

		my $dir = $self->{work_dir};
		my $gff_file2 = $dir . '/' . $self->{conf}->{gff3_file};
		return $gff_file2 if (-e $gff_file2 || $dont_parse);

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		#my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		my @f = grep { /\.gff3$/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "AUGUSTUS: gff3 output file is missing.", $/;
			return;
		}

		my $gff_file = "$dir/$f[0]";
		#parse file

		my $in  = IO::File->new($gff_file) or die "Can't open gff3 file: $!\n";
		my $out = IO::File->new("> $gff_file2") 
			or die "Can't write to gff file [$gff_file]: $!\n";
		my $gene_count = 0;
		while (my $line = <$in>) {
			next if $line =~ /^#/;
			next if $line =~ /\t(:?intron|start_codon|stop_codon|transcription_start_site|transcription_end_site)\t/;
			if ($line =~ /AUGUSTUS\tgene\t/) {
				$gene_count++;
				my $name = sprintf("AUGUSTUS%03d", $gene_count);
				$line =~ s/\tID=/\tName=$name;ID=/;
			}
			elsif ($line =~ /AUGUSTUS\tCDS\t/) {
				$line =~ s/ID=.*?;Parent=/Parent=/;
			}
			elsif ($line =~ /AUGUSTUS\ttranscript\t/) {
				$line =~ s/transcript/mRNA/;
			}
			print $out $line;
			if ($self->{clade} eq 'm' && $line =~ /\tCDS\t/) {
				$line =~ s/\tCDS\t/\texon\t/;
				print $out $line;
			}
		}
		undef $in;
		undef $out;
		#end parse file

		#return $gff_file if (-e $gff_file);
		return $gff_file2 if (-e $gff_file2);
	}

}

1;

