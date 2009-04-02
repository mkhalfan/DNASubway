#!/usr/bin/perl

use strict;
use warnings;

use IO::File;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case bundling);

my $in = new IO::File("/dev/stdin");
my $out = new IO::File("/dev/stdout", "w");

parse_options();
convert();

sub parse_options
{
	my %opts;
	GetOptions(\%opts, "input|i=s", "output|o=s", "help|h");
	print_usage() if $opts{help};
	$in = new IO::File($opts{input}) ||
		die "Error reading input $opts{input}: $!"
		if $opts{input};
	$out = new IO::File($opts{output}, "w") ||
		die "Error reading input $opts{output}: $!"
		if $opts{output};

}

sub print_usage
{
	my $prog = basename($0);
	die << "END";
usage: $prog [-i|--input <trnascan-se output>]
		[-o|--output <gff3_output] [-h|--help]
END
}

sub convert
{
	print $out "##gff-version 3\n";
	while (my $line = <$in>) {
		chomp $line;
		my @tokens = split /\s+/, $line;
		next if !validate(\@tokens);
		print_gff3_entry(\@tokens);
	}
}

sub validate
{
	my $tokens = shift;
	return scalar(@{$tokens}) == 9 &&
		$tokens->[1] =~ /^\d+$/ &&
		$tokens->[2] =~ /^\d+$/ &&
		$tokens->[3] =~ /^\d+$/ &&
		$tokens->[6] =~ /^\d+$/ &&
		$tokens->[7] =~ /^\d+$/;
}

sub print_gff3_entry
{
	my $tokens = shift;
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
		$seq_id, "tRNAScan-SE", "transcript",
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
