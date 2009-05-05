#!/usr/bin/perl -w

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();
use DNALC::Pipeline::Utils qw(random_string);
use Data::Dumper;

use strict;

#-----------------------------------------------------------------------------
my $input_file = '/home/cornel/work/100k/B.fasta';
#-----------------------------------------------------------------------------

my $proj;
my ($u) = DNALC::Pipeline::User->search( username => $ARGV[0]);

unless ($u) {
	print STDERR  "User not found.", $/;
	exit 0;
}

if ($ARGV[1]) {
	$proj = DNALC::Pipeline::Project->retrieve($ARGV[1]);
	if (!$proj || $proj->user_id != $u->id) {
		die "Unable to find project: ", $ARGV[1], $/;
	}
}
else {
	#create project
	$proj = eval {
			DNALC::Pipeline::Project->create({
				user_id => $u->id,
				name => 'Project name: '. random_string(4, 15),
			});};

	if ($@) {
		die "Error: $@", $/;
	}
	else {
		warn "project_created: id = ", $proj, ",\tname = ", $proj->name, $/;

		# create projects work directory
		if ($proj->create_work_dir) {
			warn "project's work_dir: ", $proj->work_dir, $/;
			$proj->dbi_commit;
		}
		else {
			warn "Failed to create work_dir for project [$proj]", $/;
			$proj->dbi_rollback;
			exit 0;
		}
	}
}

my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );

#print STDERR Dumper( \$wfm), $/;

my $upload_st = $wfm->get_status('upload_fasta');

if ( $upload_st->name eq 'Not processed') {
	my $fasta = $wfm->upload_sequence($input_file);

	$upload_st = $wfm->get_status('upload_fasta');
}

print STDERR "U_ST = ", $upload_st->name , $/;

if ( $upload_st->name eq 'Done') {
	my $st;
	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_repeat_masker;
 	#print STDERR Dumper( $st ), $/;
 	my $rm_st = $wfm->get_status('repeat_masker');
 	print STDERR "RM_ST = ", $rm_st->name, ($/ x 2);

	#-------------------------------------

 	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_augustus;
 	#print STDERR Dumper( $st ), $/;
 	my $a_st = $wfm->get_status('repeat_masker');
 	print STDERR  "AUGUSTUS_ST = ", $a_st->name, $/;

	#-------------------------------------
 	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_trna_scan;
 	print STDERR Dumper( $st ), $/;
 	my $t_st = $wfm->get_status('trna_scan');
 	print STDERR "TRNA_SCAN_ST = ", $t_st->name, ($/ x 2);
	#-------------------------------------
	print STDERR  '-' x 20 , $/;
	$st = $wfm->run_fgenesh;
	print STDERR Dumper( $st ), $/;
	my $f_st = $wfm->get_status('fgenesh');
	print STDERR "FGNESH_ST = ", $f_st->name, ($/ x 2);

}

=head1 TODO

Use WFM to:
0. check if fasta was uploaded
1. run RepeatMasker => updated workflow
2. Augustus
3. 

=cut

print $/;
