package DNALC::Pipeline::Process::Augustus;

use base q(DNALC::Pipeline::Process);
use IO::File ();

{
	sub new {
		my ($class, $project_dir) = @_;

		__PACKAGE__->SUPER::new('AUGUSTUS', $project_dir);
	}

	sub get_gff3_file {
		my ($self) = @_;

		#my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{output_file};
		my $dir = $self->{work_dir};

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /\.gff3$/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "AUGUSTUS: gff3 output file is missing.", $/;
			return;
		}

		my $gff_file = "$dir/$f[0]";
		my $gff_file2 = "$dir/augustus.gff3.fixed";
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
		}
		undef $in;
		undef $out;
		#end parse file

		#return $gff_file if (-e $gff_file);
		return $gff_file2 if (-e $gff_file2);
	}

}

1;

