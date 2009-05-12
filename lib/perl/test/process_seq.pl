#!/usr/bin/perl -w

use strict;
#use diagnostics;

use Readonly ();
use Data::Dumper;

use DNALC::Pipeline::Project ();

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::FGenesH ();

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

my $proj = DNALC::Pipeline::Project->retrieve($ARGV[0]);

unless ($proj) {
	print STDERR  "Project [$ARGV[0]] not found..", $/;
	exit 0;
}

#my $input  = $WORK_DIR . '/100k/'. 'B.fasta';
my $output = $proj->work_dir . '/' . 'out.gff3';
my @gffs = ();

my $rep_mask = DNALC::Pipeline::Process::RepeatMasker->new( $proj->work_dir  );
if ($rep_mask) {
	my $pretend = 0;
	$rep_mask->run(
			input => $proj->fasta_file,
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

my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $proj->work_dir, 'Monocots' );
if ($fgenesh) {
	my $pretend = 0;
	$fgenesh->run(
			input => $proj->fasta_file,
			pretend => $pretend,
			debug => 1
		);
	if (defined $fgenesh->{exit_status} && $fgenesh->{exit_status} == 0) {
		print "FGENESH: success\n";
	}
	else {
		print "FGENESH: fail\n";
	}
	my $gff_file = $fgenesh->get_gff3_file;
	push @gffs, $gff_file;
	print 'FG: gff_file: ', $gff_file, $/;
	print 'FG: duration: ', $fgenesh->{elapsed}, $/ if $fgenesh->{elapsed};
}

my $augustus = DNALC::Pipeline::Process::Augustus->new( $proj->work_dir );
if ( $augustus) {
	my $pretend = 0;
	$augustus->run(
			input => $proj->fasta_file,
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

my $trna_scan = DNALC::Pipeline::Process::TRNAScan->new( $proj->work_dir );
if ($trna_scan ) {
	my $pretend = 0;
	$trna_scan->run(
			input => $proj->fasta_file,
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
	my @args = ('/var/www/bin/gff3_merger.pl', @params, '-f', $proj->fasta_file, '-o', $output);
	print STDERR  Dumper(\@args), $/;
	system (@args) && die "Error: $!\n";
}
