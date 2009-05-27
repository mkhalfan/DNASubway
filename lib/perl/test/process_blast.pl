#!/usr/bin/perl -w

use strict;
#use diagnostics;

use Data::Dumper;

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::Blast ();

#use Bio::SeqIO ();

#------------
my $WORK_DIR = q{/home/luj/work};
#------------

# 1. read/get seq either from:
#	a.file
# 	b.genebank by id
# 	save the seq into a directory w. unique name (X.fasta)
# 2. repeat mask the sequence
# 	input: X.fasta
# 	output: R.fasta, X.masked
# 3. run augustus
# 	input: X.fasta
# 	output: A.gff3
# 4. run FGenesH
# 	input: X.fasta
# 	output: ?
# 5. run blast
# 	input: R.fasta
# 	output: B.gff3
# 6. merge gff3 files
# 7. create gbrowse conf
# 8. view results in browser

#my $seqio = Bio::SeqIO->new(-file => $WORK_DIR . '/'. 'A.fasta', -format => 'Fasta');
#my $seq = $seqio->next_seq;
#print $seq->seq, $/;

my $input  = $WORK_DIR . '/100k.fasta';
my $output = $WORK_DIR . '/' . 'out.gff3';
my @gffs = ();

my $blastn = DNALC::Pipeline::Process::Blast->new( $WORK_DIR, 'blastn' );
if ($blastn ) {
	$blastn->run(
			input => $input,
			#debug => 1,
		);
	if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
		print "BLASTN: success\n";
	}
	else {
		print "BLASTN: fail\n";
		print "exit_code= ", $blastn->{exit_status}, $/;
		print $blastn->{cmd}, $/;
	}
	my $gff_file = $blastn->get_gff3_file;
	push @gffs, $gff_file if $gff_file;
	print 'BLASTN: gff_file: ', $gff_file, $/ if $gff_file;
	print 'BLASTN: duration: ', $blastn->{elapsed}, $/;
}

my $blastx = DNALC::Pipeline::Process::Blast->new( $WORK_DIR, 'blastx' );
if ($blastx ) {
	my $pretend = 0;
	$blastx->run(
			input => $input,
			#debug => 1,
		);
	if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
		print "BLASTX: success\n";
	}
	else {
		print "BLASTX: fail\n";
		print "exit_code= ", $blastx->{exit_status}, $/;
		print $blastx->{cmd}, $/;
	}
	my $gff_file = $blastx->get_gff3_file;
	push @gffs, $gff_file if $gff_file;
	print 'BLASTX: gff_file: ', $gff_file, $/ if $gff_file;
	print 'BLASTX: duration: ', $blastx->{elapsed}, $/;
}
print "\n";

1;
