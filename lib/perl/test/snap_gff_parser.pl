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

my $file = '/home/cornel/work/100k/snap_output.gff';


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
			$genes{$gene_name}->{end} = $data[4];
		}
		else {
			$genes{$gene_name}->{data} = [\@data];
			$genes{$gene_name}->{start} = $data[3];
			$genes{$gene_name}->{sign} = $data[6];
			$genes{$gene_name}->{end} = $data[4];
		}

		print $_, "\n";
	}
	print '-' x 20, $/;
	#print STDERR Dumper( \%genes), $/;
	foreach my $gene_name (sort keys %genes) {
		my $g = $genes{$gene_name};
		my @data = @{$genes{$gene_name}->{data} };
		#print $gene_name, "\t", $g->{start}, "->", $g->{end}, $/;
		#for $g->{data})
		#print  Dumper( $g->{data}), $/;
		print $data[0]->[0], "\t", $data[0]->[1], "\tgene\t", $g->{start}, "\t", $g->{end}, 
				"\t0\t", $g->{sign}, "\t.\t", $gene_name, "\n";
		for (@data) {
			$_->[2] =~ s/Exon/exon/;
			$_->[2] =~ s/(?:Eterm|Einit)/CDS/;
			print join ("\t", @$_), "\n";
			#for (@$_) {
			#	print $_;
			#}
		}
	}
}
undef $in;
undef $out;
