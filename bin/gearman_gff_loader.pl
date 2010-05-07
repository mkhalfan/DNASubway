#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use Data::Dumper;
use File::Basename;
use Gearman::Worker ();
use DNALC::Pipeline::Config ();
use Storable qw/thaw/;


my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $worker = Gearman::Worker->new;
$worker->job_servers(@{$config->{GEARMAN_SERVERS}});

sub run_load_analysis_results {
	my $gearman = shift;
	my $args = thaw($gearman->arg);
	my ($username, $profile, $alg, $file, $tries) = @$args;

	sleep(5);
	
	my $cmd = $config->{EXE_PATH} . '/load_analysis_results.pl';
	my @args = ('--username', $username,
				'--profile', $profile,
				'--algorithm', $alg,
				'--gff', $file
			);
	push @args, ('--tries', $tries) if $tries;
	print STDERR  "\n\nGEARMAN LOADING DATA:\n", $cmd, " ", "@args", $/;

	system($cmd, @args);
}

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

$worker->register_function("load_analysis_results", \&run_load_analysis_results);
$worker->register_function("${script_name}_exit" => sub { 
	$work_exit = 1; 
});

$worker->work( stop_if => $stop_if ) while !$work_exit;
exit 0;
