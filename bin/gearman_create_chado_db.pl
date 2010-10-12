#!/usr/bin/perl 

use strict;
#use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Chado::Utils ();

use File::Basename;
use Gearman::Worker ();
use Storable qw(freeze);

use Data::Dumper;

{
	my $db_re = qr/^[a-z0-9_-]+$/i;

	sub run_create_chado_db {
		my $gearman = shift;
		my $db_name = $gearman->arg;

		unless (defined $db_name && $db_name =~ $db_re) {
			return "ERROR: Invalid db name!";
		}
		my $st = undef;

		my $conf = DNALC::Pipeline::Config->new->cf('PIPELINE');
		my %args = (
			'dumppath'  => $conf->{GMOD_DUMPFILE},
			'profile'   => $conf->{GMOD_PROFILE},
		);

		$ENV{GMOD_ROOT} ||= $conf->{GMOD_ROOT};

		my $cutils = DNALC::Pipeline::Chado::Utils->new(%args);

		unless ($cutils->check_db_exists($db_name)) {
			$cutils->username($db_name);
			eval {
				$cutils->create_db(1); #quiet
			};
			if ($@) {
				#print STDERR "create_chado_db: ", $@, $/;
				$st = "Error: $@";
			}
			else {
				$st = "OK";
			}
		}
		else {
			$st = "OK"; #really?!
		}

		return $st;
	}


	#-------------------------------------------------

	my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');

	my $worker = Gearman::Worker->new;
	$worker->job_servers(@{$pcf->{GEARMAN_SERVERS}});

	$worker->register_function("create_chado_db", \&run_create_chado_db);

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
}

