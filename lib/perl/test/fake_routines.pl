#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  fake_routines.pl
#
#        USAGE:  ./fake_routines.pl  
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
#      CREATED:  05/29/09 10:22:24
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;



use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();
use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::Chado::Utils ();
use DNALC::Pipeline::Sample ();
use Data::Dumper;


my $SAMPLEID = 4;
$ENV{GMOD_ROOT} = '/usr/local/gmod';


my $sample = DNALC::Pipeline::Sample->new($SAMPLEID);
die 'Sample not found ' unless $sample;
#my $rc = $sample->copy_results({
#			routine => 'trna_scana',
#			project_dir => '/tmp',
#			common_name => 'ocaua-mica',
#		});
#my $rc = $sample->copy_fasta({
#			project_dir => '/tmp',
#			common_name => 'ocaua-mica',
#		});

#-----------------------------------------------------------------------------
my $username = 'guest';
if (!$username || $username =~ /[^a-z0-9_-]/i) {
	print STDERR  "Username missing or not well formated.", $/;
	exit 0;
}

my ($u) = DNALC::Pipeline::User->search( username => $username);

unless ($u ) {
	$u = DNALC::Pipeline::User->create({
			username => $username,
			password => '123',
			email => 'ghiban@cshl.edu',
			name_first => 'Cornel',
			name_last => 'Ghiban'
		});
}
my ($proj) = DNALC::Pipeline::Project->retrieve(280);
unless ($proj) {
	my $organism = $sample->organism;
	my @subnames = split /\s/, $organism;
	my $common_name = $sample->common_name;
	#-----------------------------------------------------------------------------
	#create project
	$proj = eval {
		DNALC::Pipeline::Project->create({
			user_id => $u->id,
			name => 'Project name: '. random_string(4, 15),
			organism => $organism,
			common_name => $common_name,
			crc => '',
			sample => $SAMPLEID,
		});
	};
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

#my $cf = DNALC::Pipeline::Config->new;
#my $pcf = $cf->cf('PIPELINE');

my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
my $upload_st = $wfm->get_status('upload_fasta');

if ( $upload_st->name eq 'Not processed') {
	my $fasta = $wfm->upload_sequence();

	$upload_st = $wfm->get_status('upload_fasta');
}

print STDERR "U_ST = ", $upload_st->name , $/;


if ( $upload_st->name eq 'Done') {
	my $st;
	my $rm_st = $wfm->get_status('repeat_masker');
	#if ( $rm_st->name ne 'Done') {
		print STDERR  '-' x 20 , $/;
		$st = $wfm->run_repeat_masker;
		$rm_st = $wfm->get_status('repeat_masker');
		print STDERR "RM_ST = ", $rm_st->name, ($/ x 2);
	#}

    #-------------------------------------
  	print STDERR  '-' x 20 , $/;
  	$st = $wfm->run_blastx;
  	print STDERR Dumper( $st ), $/;
  	my $bx_st = $wfm->get_status('blastx');
  	print STDERR "BLASTX_ST = ", $bx_st->name, ($/ x 2);
	#-------------------------------------

#    	print STDERR  '-' x 20 , $/;
#    	$st = $wfm->run_augustus;
#    	my $a_st = $wfm->get_status('augustus');
#    	print STDERR  "AUGUSTUS_ST = ", $a_st->name, $/;

 	#-------------------------------------
#   	print STDERR  '-' x 20 , $/;
#   	$st = $wfm->run_trna_scan;
#   	print STDERR Dumper( $st ), $/;
#   	my $t_st = $wfm->get_status('trna_scan');
#   	print STDERR "TRNA_SCAN_ST = ", $t_st->name, ($/ x 2);
    #-------------------------------------
#   	print STDERR  '-' x 20 , $/;
#   	$st = $wfm->run_fgenesh;
#   	print STDERR Dumper( $st ), $/;
#   	my $f_st = $wfm->get_status('fgenesh');
#   	print STDERR "FGNESH_ST = ", $f_st->name, ($/ x 2);
	#-------------------------------------
}

#let apache be able to work with projects files..
system('chmod -R a+w ' . $proj->work_dir);
