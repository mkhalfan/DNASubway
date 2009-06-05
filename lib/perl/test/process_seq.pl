#!/usr/bin/perl -w

use strict;
#use diagnostics;

use Data::Dumper;

use DNALC::Pipeline::Project ();

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::RepeatMasker2 ();
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::Snap ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::FGenesH ();
use DNALC::Pipeline::Process::Blast ();

my $proj = DNALC::Pipeline::Project->retrieve($ARGV[0] || 229);

unless ($proj) {
	print STDERR  "Project [$ARGV[0]] not found..", $/;
	exit 0;
}

my $output = $proj->work_dir . '/' . 'out.gff3';
my @gffs = ();


my $rep_mask = DNALC::Pipeline::Process::RepeatMasker->new( $proj->work_dir, $proj->clade);
if ($rep_mask) {
	my $pretend = 0;
	$rep_mask->run(
			input => $proj->fasta_file,
			pretend => $pretend,
			debug => 1,
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
my $rm2 = DNALC::Pipeline::Process::RepeatMasker2->new( $proj->work_dir, $proj->clade );
print STDERR Dumper( $rm2 ), $/;
if ( $rm2 ) {
	$rm2->run(
			input => $proj->fasta_file,
			debug => 1,
		);
	if (defined $rm2->{exit_status} && $rm2->{exit_status} == 0) {
		print "rm2: success\n";
		
		#my $gff_file = $rm2->get_gff3_file;
		#push @gffs, $gff_file;
		#print 'SNAP: gff_file: ', $gff_file, $/;
		print 'SNAP: duration: ', $rm2->{elapsed}, $/;
	}
	else {
		print "SNAP: fail\n";
	}
}

my $snap = DNALC::Pipeline::Process::Snap->new( $proj->work_dir, $proj->clade );
if ( $snap) {
	my $pretend = 0;
	$snap->run(
			input => $proj->fasta_masked_nolow,
			pretend => $pretend,
			debug => 1,
		);
	if (defined $snap->{exit_status} && $snap->{exit_status} == 0) {
		print "SNAP: success\n";
		
		my $gff_file = $snap->get_gff3_file;
		push @gffs, $gff_file;
		print 'SNAP: gff_file: ', $gff_file, $/;
		print 'SNAP: duration: ', $snap->{elapsed}, $/;
	}
	else {
		print "SNAP: fail\n";
	}

}


my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $proj->work_dir, $proj->clade );
if ($fgenesh) {
	$fgenesh->run(
			input => $proj->fasta_masked_nolow,
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
my $augustus = DNALC::Pipeline::Process::Augustus->new( $proj->work_dir , $proj->clade);
if ( $augustus) {
	$augustus->run(
			input => $proj->fasta_masked_nolow,
			debug => 1,
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
	$trna_scan->run(
			input => $proj->fasta_file,
			debug => 1,
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

my $blastn = DNALC::Pipeline::Process::Blast->new( $proj->work_dir, 'blastn' );
if ($blastn) {
	$blastn->run(
			input => $proj->fasta_masked_xsmall,
			debug => 1,
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

print "\n\n";

my $blastx = DNALC::Pipeline::Process::Blast->new( $proj->work_dir, 'blastx' );
if ($blastx ) {
	$blastx->run(
			input => $proj->fasta_masked_xsmall,
			debug => 1,
		);
	if (defined $blastx->{exit_status} && $blastx->{exit_status} == 0) {
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



if (@gffs) {
	my @params = ();
	for (@gffs) {
		push @params, ('-g', $_);
	}
	my @args = ('/var/www/bin/gff3_merger.pl', @params, '-f', $proj->fasta_file, '-o', $output);
	print STDERR  Dumper(\@args), $/;
	system (@args) && die "Error: $!\n";
}
