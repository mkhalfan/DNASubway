#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use Data::Dumper;
use File::Basename;
use Gearman::Worker ();
use DNALC::Pipeline::Config ();

use Storable qw/nfreeze/;

my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');

sub run_apolloinsert {
	my $gearman = shift;
	my $args = $gearman->arg;
	my $apollo = $config->{APOLLO_HEADLESS};
	if (defined $ENV{DISPLAY}) {
		print STDERR  "DISPLAY = ", $ENV{DISPLAY}, $/;
		undef $ENV{DISPLAY};
	}
	print STDERR "\n", $apollo, ' ', $args, "\n----\n";
	my $rc = system($apollo . ' ' . $args);
	print STDERR "RC = ", $rc, $/;
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

my $worker = Gearman::Worker->new;
$worker->job_servers(@{$config->{GEARMAN_SERVERS}});

$worker->register_function("apollo_insert", \&run_apolloinsert);

$worker->register_function("${script_name}_exit" => sub { 
	$work_exit = 1; 
});

$worker->work( stop_if => $stop_if ) while !$work_exit;
exit 0;
