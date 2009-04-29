#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling);
use IO::File;
use File::Basename;

my $out = new IO::File("/dev/stdout", "w");
my $fasta;
my @gff3;

parse_options();
merge_gff3();

sub parse_options
{
	my $gff3_out;
	my $fasta_in;
	my $help;
	GetOptions("g|gff3=s" => \@gff3, "f|fasta=s" => \$fasta_in,
			"o|output=s" => \$gff3_out,
			"h|help" => \$help);
	die "No GFF3 input provided" if scalar(@gff3) == 0;
	die "No FASTA input provided" if !$fasta_in;
	print_usage() if $help;
	$fasta = new IO::File($fasta_in) || die "Error reading fasta: $!";
	$out = new IO::File($gff3_out, "w") || die "Error writing GFF3: $!"
		if $gff3_out;
}

sub print_usage
{
	my $prog = basename($0);
	die << "END";
usage: $prog -g|--gff3 <gff3> [-g|--gff3 <gff3 ...]
	-f|--fasta <fasta> [-o|--output <gff3_output>] [-h|--help]
END
}

sub merge_gff3
{
	print $out "##gff-version 3\n";
	process_fasta();
	foreach my $g (@gff3) {
		my $in = new IO::File($g) || die "Error reading GFF3: $!";
		while (my $line = <$in>) {
			my @tokens = split /\t/, $line;
			next if scalar(@tokens) != 9;
			print $out $line;
		}
	}
	print $out "###\n";
	print $out "##FASTA\n";
	while (my $line = <$fasta>) {
		print $out $line;
	}
}

sub process_fasta
{
	my $id;
	my $len = 0;
	while (my $line = <$fasta>) {
		if ($line =~ /^>/) {
			my @tokens = split /\s+/, $line;
			$id = substr $tokens[0], 1;
		}
		else {
			chomp $line;
			$len += length($line);
		}
	}
	#print $out "$id\tDNALC\tchromosome\t1\t$len\t.\t.\t.\tID=$id;Name=$id\n";
	$fasta->seek(0, 0);
}
