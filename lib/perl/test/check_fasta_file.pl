#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  check_fasta_file.pl
#
#        USAGE:  ./check_fasta_file.pl  
#
#  DESCRIPTION:  File to check if a fasta file contains valid data
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban, ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  05/12/09 17:32:46
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Bio::SeqIO ();
use Bio::Seq ();
use Data::Dumper;

my $file = "/var/www/vhosts/pipeline.dnalc.org/var/projects/0104/fasta.fa";
#my $file = "/home/cornel/gbrowse.template";
#my $file = "/home/cornel/fasta.fa";

my $common_name = 'rice';
my $in  = Bio::SeqIO->new(-file => $file,
						-format => "Fasta");

my $seq = $in->next_seq();
print STDERR  $seq, $/;
if ($seq) {
	print "alphabet:", $seq->alphabet, $/;
	print "len: ", $seq->length, $/;
	print "display: ", $seq->display_id, $/;
	my $seq2 = Bio::Seq->new( -display_id => $common_name );
	print "display: ", $seq2->display_id, $/;

	# set text to upper case
	$seq2->seq(uc $seq->subseq(1,$seq->length),'dna');
	my $out = Bio::SeqIO->new(-file => "> /tmp/rice.fasta", -format => "Fasta");
	$out->write_seq($seq2);
}
#print STDERR Dumper( $seq ), $/;
