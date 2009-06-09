#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  snap_gff_parser.pl
#
#        USAGE:  ./snap_gff_parser.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  06/01/09 11:51:52
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use IO::File;
use Data::Dumper;

my $file = '/home/cornel/work/100k/stdout.txt';


my $in  = IO::File->new;
my $out = IO::File->new;
if ($in->open($file, 'r')) {
	my $last_gene = '';
	my $snippet = '';
	my %genes = ();
	while (<$in>) {
		chomp;
		next if $_ =~ /^#/;
		next if $_ =~ /\tEsngl\t/;
		my @data = split /\t/;
		next if @data != 9;
		$data[8] =~ s/\.(\d+)$/sprintf(".%03d", $1)/e;
		my $gene_name = $data[8];
		if (exists $genes{$gene_name}) {
			push @{$genes{$gene_name}->{data}}, \@data;
			$genes{$gene_name}->{start} = $data[3] < $genes{$gene_name}->{start}
													? $data[3]
													: $genes{$gene_name}->{start};
			$genes{$gene_name}->{end} = $data[4] > $genes{$gene_name}->{end}
													? $data[4]
													: $genes{$gene_name}->{end};
		}
		else {
			$genes{$gene_name}->{data} = [\@data];
			$genes{$gene_name}->{sign} = $data[6];
			$genes{$gene_name}->{start} = $data[3];
			$genes{$gene_name}->{end} = $data[4];
		}

		print $_, "\n";
	}

	print '-' x 20, $/;
	#print STDERR Dumper( \%genes), $/;
	foreach my $gene_name (sort keys %genes) {
		#next if $genes{$gene_name}->{sign} eq '+';
		my $g = $genes{$gene_name};
		my @data = @{$genes{$gene_name}->{data} };
		#if ($g->{sign} eq '-' && $g->{start} > $g->{end}) {
		#	($g->{start}, $g->{end}) = ($g->{end}, $g->{start});
		#}

		#print $gene_name, "\t", $g->{start}, "->", $g->{end}, $/;
		print $data[0]->[0], "\t", $data[0]->[1], "\tgene\t", $g->{start}, "\t", $g->{end}, 
				"\t0\t", $g->{sign}, "\t.\t", $gene_name, "\n";
		for (@data) {
			my $col3 = $_->[2];
			$col3 =~ s/(?:Eterm|Einit|Exon)/CDS/;
			$_->[2] = $col3;
			$_->[8] = "Parent=m" . $_->[8];
			print join ("\t", @$_), "\n";

			$col3 =~ s/CDS/exon/;
			$_->[2] = $col3;
			print join ("\t", @$_), "\n";

		}
		#last;
	}
}
undef $in;
undef $out;
