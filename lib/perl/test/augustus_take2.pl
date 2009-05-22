#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  augustus_take2.pl
#
#        USAGE:  ./augustus_take2.pl  
#
#  DESCRIPTION:  a rewrite of augustus config file
#
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  05/22/09 12:36:02
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();
use DNALC::Pipeline::Utils qw(random_string);
use Data::Dumper;

#-----------------------------------------------------------------------------
my $input_file = '/home/cornel/work/100k/B.fasta';
#-----------------------------------------------------------------------------

my $proj;
my ($u) = DNALC::Pipeline::User->search( username => 'H9VV');

unless ($u) {
	print STDERR  "User not found.", $/;
	exit 0;
}

my $pid = $ARGV[1] || 147;
$proj = DNALC::Pipeline::Project->retrieve($pid);
if (!$proj) {
	die "Unable to find project: ", $pid, $/;
}

print STDERR  'WD = ', $proj->work_dir, $/;

print STDERR Dumper( $proj ), $/;

my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );


my $upload_st = $wfm->get_status('upload_fasta');
#print STDERR Dumper( $upload_st), $/;
#print STDERR Dumper( \$wfm), $/;

if ( $upload_st->name eq 'Not processed') {
	my $fasta = $wfm->upload_sequence($input_file);

	$upload_st = $wfm->get_status('upload_fasta');
}

print STDERR "U_ST = ", $upload_st->name , $/;

if ( $upload_st->name eq 'Done') {
	my $st;
	#-------------------------------------

	#print STDERR  '-' x 20 , $/;
	#$st = $wfm->run_augustus;
	#my $a_st = $wfm->get_status('repeat_masker');
	#print STDERR  "AUGUSTUS_ST = ", $a_st->name, $/;

	my $augustus = DNALC::Pipeline::Process::Augustus->new( $proj->work_dir );
	print STDERR Dumper( $augustus), $/;
	if ( $augustus) {
		my $pretend = 0;
		$augustus->run(
				input => $proj->fasta_file,
				pretend => $pretend,
				debug => 1,
			);
		if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
			print "AUGUSTUS: success\n";
		}
		else {
			print "AUGUSTUS: fail\n";
		}
		my $gff_file = $augustus->get_gff3_file;
		#push @gffs, $gff_file;
		print 'AUGUSTUS: gff_file: ', $gff_file, $/;
		print 'AUGUSTUS: duration: ', $augustus->{elapsed}, $/;
	}
}

=head1 TODO

Use WFM to:
0. check if fasta was uploaded
1. run RepeatMasker => updated workflow
2. Augustus
3. 

=cut

print $/;

