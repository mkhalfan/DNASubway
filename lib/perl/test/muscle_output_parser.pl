#!/usr/bin/perl

use common::sense;

use Bio::AlignIO;
use Data::Dumper;

my $file = '/var/www/vhosts/pipeline.dnalc.org/var/projects/phylogenetics/0005/algnbEPKd/MUSCLE/output.fasta';

my $l_trim = 20;
my $r_trim = 10;

my $trimmed_fasta = '';

my $aio = Bio::AlignIO->new('-file' => $file);
while (my $aln = $aio->next_aln()) {
	#print STDERR  $aln, $/;
	print $aln->length, "\n";
	print $aln->no_residues, "\n";
	print $aln->is_flush, "\n";
	print $aln->no_sequences, "\n";
	print $aln->percentage_identity, "\n";
	#print $aln->consensus_string(50), "\n";
	for my $seq ($aln->each_seq) {
		print STDERR  "\t", $seq->display_id, $/;
		next;
		#print STDERR  "\t", $seq->seq, $/;
		my $s = $seq->seq;

		print STDERR  "1. ", length($s), $/;
		#substr $s, 0, $l_trim = '';
		$s =~ s/^.{$l_trim}//;
		print STDERR  "2. ", length($s), $/;
		#substr $s, length($s) - $r_trim, $r_trim = '';
		$s =~ s/.{$r_trim}$//;
		print STDERR  "3. ", length($s), $/;

		$trimmed_fasta .= '>' . $seq->display_id . "\n";
		$trimmed_fasta .= $s . "\n";
	}

}

#print STDERR Dumper( $aln ), $/;
