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


my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');
$worker->register_function("augustus", \&run_augustus);
$worker->register_function("repeat_masker", \&run_repeatmasker);
$worker->register_function("trna_scan", \&run_trnascan);
$worker->register_function("snap", \&run_snap);
$worker->register_function("fgenesh", \&run_fgenesh);

$worker->work while 1;
