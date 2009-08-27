#!/usr/bin/perl 

use strict;
use lib "/var/www/lib/perl";

use Data::Dumper;
use Gearman::Worker ();
use DNALC::Pipeline::Config ();


sub run_apolloinsert {
	my $gearman = shift;
	my $args = $gearman->arg;
    my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');
	my $apollo = $config->{APOLLO_HEADLESS};
	print $apollo.' '.$args."\n----\n";	
	system($apollo.' '.$args);
}

#-------------------------------------------------

my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');
$worker->register_function("apollo_insert", \&run_apolloinsert);

$worker->work while 1;
