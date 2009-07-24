#!/usr/bin/perl -w

use strict;
#use diagnostics;

use Data::Dumper;

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::Blast ();

#use Bio::SeqIO ();

#------------
my $WORK_DIR = q{/home/cornel/work/10k};
#------------

my $input  = $WORK_DIR . '/A.fasta';
my $output = $WORK_DIR . '/' . 'out.gff3';

my $blastn = DNALC::Pipeline::Process::Blast->new( $WORK_DIR, 'blastn_user' );
if ($blastn ) {
	$blastn->run(
			input => $input,
			debug => 1,
		);
	if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
		print "BLASTN: success\n";
		my $gff_file = $blastn->get_gff3_file;
		print 'BLASTN: gff_file: ', $gff_file, $/ if $gff_file;
	}
	else {
		print "BLASTN: fail\n";
		print "exit_code= ", $blastn->{exit_status}, $/;
		print $blastn->{cmd}, $/;
	}
	print 'BLASTN: duration: ', $blastn->{elapsed}, $/;
}

__END__
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
