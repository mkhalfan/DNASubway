package DNALC::Pipeline::Process::TRNAScan;

use base q(DNALC::Pipeline::Process);
use Data::Dumper;
#use strict;

{

	sub new {
		my ($class, $project_dir) = @_;

		__PACKAGE__->SUPER::new('TRNA_SCAN', $project_dir);
	}

	sub convert2GFF3 {
		my ($self) = @_;

		my $gff_file = $self->{work_dir} . '/' . $self->{conf}->{gff3_file};
		my $dir = $self->{work_dir};

		#find file to parse
		opendir(DIR, $dir) or die "Can't opendir $dir: $!";
		my @f = grep { /$self->{conf}->{file_to_parse}/ && -f "$dir/$_" } readdir(DIR);
		unless (@f == 1) {
			print STDERR "TRNA_SCAN: gff3 output file is missing.", $/;
			return;
		}

		my $file_to_parse = "$dir/$f[0]";

		# it's ok to create an empty file?
		#return if -z $file_to_parse;

		my $in  = IO::File->new($file_to_parse) or die "Can't open tRNA_SCAN file: $!\n";
		my $out = IO::File->new("> $gff_file") 
			or die "Can't write to gff file [$gff_file]: $!\n";
		print $out "##gff-version 3\n";
		while (my $line = <$in>) {
			chomp $line;
			my @tokens = split /\s+/, $line;
			next unless _validate(\@tokens);
			_print_gff3_entry($out, \@tokens);
		}

		undef $in;
		undef $out;
		return $gff_file;
	}


	sub _validate {

		my $tokens = shift;
		return scalar(@{$tokens}) == 9 &&
			$tokens->[1] =~ /^\d+$/ &&
			$tokens->[2] =~ /^\d+$/ &&
			$tokens->[3] =~ /^\d+$/ &&
			$tokens->[6] =~ /^\d+$/ &&
			$tokens->[7] =~ /^\d+$/;
	}

	sub _print_gff3_entry {

		my ($out, $tokens) = @_;
		my ($seq_id, $trna_num, $begin, $end, $type, $codon, $intron_begin,
			$intron_end, $score) = @{$tokens};
		my $strand = $begin < $end ? "+" : "-";
		($begin, $end) = ($end, $begin) if $strand eq "-";
		my $gene_id = sprintf("TRNASCANPREDICTION%.6d", --$trna_num);
		my $transcript_id = sprintf("TRNASCANPREDICTIONtRNA%.6d", $trna_num);
		my $exon_id = sprintf("TRNASCANPREDICTIONexon%.6d", $trna_num);

		# print gene
		printf $out "%s\t%s\t%s\t%d\t%d\t%.2f\t%s\t%s\t%s\n",
			$seq_id, "tRNAScan-SE", "gene",
			$begin, $end, $score, $strand, ".",
			sprintf("ID=%s;Name=%s", $gene_id, $gene_id);
		# print transcript
		printf $out "%s\t%s\t%s\t%d\t%d\t%.2f\t%s\t%s\t%s\n",
			$seq_id, "tRNAScan-SE", "tRNA",
			$begin, $end, $score, $strand, ".",
			sprintf("ID=%s;Name=%s;Parent=%s",
				$transcript_id, $transcript_id, $gene_id);
		# print exon
		printf $out "%s\t%s\t%s\t%d\t%d\t%.2f\t%s\t%s\t%s\n",
			$seq_id, "tRNAScan-SE", "exon",
			$begin, $end, $score, $strand, ".",
			sprintf("ID=%s;Name=%s;Parent=%s",
				$exon_id, $exon_id, $transcript_id);
	}

	sub get_gff3_file {
		my ($self) = @_;

		my $gff_file = $self->convert2GFF3;
		return $gff_file if ($gff_file && -e $gff_file && !-z $gff_file);
	}

}

1;

