#!/usr/bin/perl 

use common::sense;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::FGenesH ();

use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();

use DNALC::Pipeline::Config();

use Data::Dumper;
use File::Basename;
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

#-------------------------------------------------

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $worker = Gearman::Worker->new;
$worker->job_servers(@{$pcf->{GEARMAN_SERVERS}});

$worker->register_function("augustus", \&run_augustus);
$worker->register_function("trna_scan", \&run_trnascan);
$worker->register_function("snap", \&run_snap);
$worker->register_function("fgenesh", \&run_fgenesh);

#-------------------------------------------------
my $script_name = fileparse($0);
$script_name =~ s/\.[^.]*$//;

my $work_exit = 0;
my ($is_idle, $last_job_time);

my $stop_if = sub { 
	($is_idle, $last_job_time) = @_; 

	if ($work_exit) { 
		print STDERR  "*** [$script_name] exiting.. \n", $/;
		return 1; 
	}
	return 0; 
}; 

#-------------------------------------------------

$worker->register_function("${script_name}_exit" => sub { 
	$work_exit = 1; 
});

#-------------------------------------------------
$worker->work( stop_if => $stop_if ) while !$work_exit;

exit 0;

