#!/usr/bin/perl

use strict;
use DNALC::Pipeline::Config ();
use Gearman::Client ();
use Storable qw/thaw freeze/;
use Data::Dumper;

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $client = Gearman::Client->new;
my $sx = $client->job_servers(@{$pcf->{GEARMAN_SERVERS}});

my $out = $client->do_task('create_chado_db', 'labush 1', {
			timeout => 6,
			on_fail => sub {
				print "On fail: ", @_, $/;
			},
			on_retry => sub {
				print "On retry: ", @_, $/;
			},
		});


print STDERR  "Done1: [", $$out, "]", $/ 
	if $out;
#my $xx = thaw $$out;
#print STDERR  "Done2: [", $$xx, "]", $/;
