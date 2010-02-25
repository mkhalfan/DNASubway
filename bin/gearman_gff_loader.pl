#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use Data::Dumper;
use Gearman::Worker ();
use DNALC::Pipeline::Config ();
use Storable qw/thaw/;


my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');

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

my $worker = Gearman::Worker->new;
$worker->job_servers(@{$config->{GEARMAN_SERVERS}});
$worker->register_function("load_analysis_results", \&run_load_analysis_results);

$worker->work while 1;
