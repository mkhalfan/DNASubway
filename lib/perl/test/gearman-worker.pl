#!/usr/bin/perl 

use strict;
use lib "/var/www/lib/perl";

use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::FGenesH ();

use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();

use Data::Dumper;
use Gearman::Worker ();
use Storable qw(freeze);

sub run_augustus {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_augustus;
   return freeze $st;
}

sub run_repeatmasker {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_repeat_masker;
   return freeze $st;
}

sub run_snap {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_snap;
   return freeze $st;
}


sub run_trnascan {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_trna_scan;
   return freeze $st;
}

sub run_fgenesh {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_fgenesh;
   return freeze $st;
}

sub run_blastn {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_blastn;
   return freeze $st;
}

sub run_blastx {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_blastx;
   return freeze $st;
}

sub run_blastn_user {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_blastn_user;
   return freeze $st;
}

sub run_blastx_user {
   my $gearman = shift;
   my $pid = $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_blastx_user;
   return freeze $st;
}
#-------------------------------------------------

my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');

$worker->register_function("augustus", \&run_augustus);
$worker->register_function("repeat_masker", \&run_repeatmasker);
$worker->register_function("trna_scan", \&run_trnascan);
$worker->register_function("snap", \&run_snap);
$worker->register_function("fgenesh", \&run_fgenesh);
$worker->register_function("blastn", \&run_blastn);
$worker->register_function("blastx", \&run_blastx);
$worker->register_function("blastn_user", \&run_blastn_user);
$worker->register_function("blastx_user", \&run_blastx_user);

#-------------------------------------------------
my $work_exit = 0;
my ($is_idle, $last_job_time);

my $stop_if = sub { 
	($is_idle, $last_job_time) = @_; 
	#print STDERR  "Routines worker is idle = $is_idle", $/;

	if ($work_exit) { 
		#$work_exit = 0;
		print STDERR  "*** Routines worker exiting.. \n", $/;
		return 1; 
	}
	return 0; 
}; 

#-------------------------------------------------

$worker->register_function(routines_check_stop_if =>  sub { 
	return freeze([$is_idle, $last_job_time]); 
});

$worker->register_function(routines_worker_exit => sub { 
	$work_exit = 1; 
});

#-------------------------------------------------
#$worker->work while 1;
$worker->work( stop_if => $stop_if ) while !$work_exit;

exit 0;

