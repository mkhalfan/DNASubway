#!/usr/bin/perl -w

use strict;
#use diagnostics;

use Readonly ();
use Data::Dumper;

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::TRNAScan ();
#use Bio::SeqIO ();

#------------
Readonly::Scalar my $WORK_DIR => q{/home/cornel/work};
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
# 4. fun FGeneH
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

my $input  = $WORK_DIR . '/100k/'. 'B.fasta';
my $output = $WORK_DIR . '/' . 'out.gff3';
my @gffs = ();

my $rep_mask = DNALC::Pipeline::Process::RepeatMasker->new;
if ($rep_mask) {
	my $pretend = 0;
	$rep_mask->run(
			input => $input,
			# FIXME - ideally we should not give this as param
			#output_dir => $WORK_DIR . '/' . 'repeat_masker',
			pretend => $pretend,
		);
	if (defined $rep_mask->{exit_status} && $rep_mask->{exit_status} == 0) {
		print "REPEAT_MASKER: success\n";
	}
	else {
		print "REPEAT_MASKER: fail\n";
	}
	my $gff_file = $rep_mask->get_gff3_file;
	push @gffs, $gff_file;
	print 'RM: gff_file: ', $gff_file, $/;
	print 'RM: duration: ', $rep_mask->{elapsed}, $/ if $rep_mask->{elapsed};
}

my $augustus = DNALC::Pipeline::Process::Augustus->new;
if ( $augustus) {
	my $pretend = 0;
	$augustus->run(
			input => $input,
			output_file => $augustus->{work_dir} . '/' . 'augustus.gff3',
			pretend => $pretend,
		);
	if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
		print "AUGUSTUS: success\n";
	}
	else {
		print "AUGUSTUS: fail\n";
	}
	my $gff_file = $augustus->get_gff3_file;
	push @gffs, $gff_file;
	print 'AUGUSTUS: gff_file: ', $gff_file, $/;
	print 'AUGUSTUS: duration: ', $augustus->{elapsed}, $/;
}

my $trna_scan = DNALC::Pipeline::Process::TRNAScan->new;
if ($trna_scan ) {
	my $pretend = 0;
	$trna_scan->run(
			input => $input,
			# FIXME - ideally we should not give this as param
			output_file => $trna_scan->{work_dir} . '/' . 'output.out',
			#debug => 1,
			pretend => $pretend,
		);
	if (defined $trna_scan->{exit_status} && $trna_scan->{exit_status} == 0) {
		print "TRNA_SCAN: success\n";
	}
	else {
		print "TRNA_SCAN: fail\n";
		print "exit_code= ", $trna_scan->{exit_status}, $/;
		#print $trna_scan->{cmd}, $/;
	}
	my $gff_file = $trna_scan->get_gff3_file;
	push @gffs, $gff_file if $gff_file;
	print 'TS: gff_file: ', $gff_file, $/ if $gff_file;
	print 'TS: duration: ', $trna_scan->{elapsed}, $/;
}
print "\n";

if (@gffs) {
	my @params = ();
	for (@gffs) {
		push @params, ('-g', $_);
	}
	my @args = ('./tests/gff3_merger.pl', @params, '-f', $input, '-o', $output);
	print STDERR  "@args", $/;
	system (@args) && die "Error: $!\n";
}
