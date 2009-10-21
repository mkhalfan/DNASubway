#!/usr/bin/perl

use strict;

use DNALC::Pipeline::CacheMemcached ();
use Data::Dumper;

my $m = DNALC::Pipeline::CacheMemcached->new;

#print STDERR Dumper( $m), $/;
#$mc->set('b', 12);
#print STDERR  $mc->get('b'), $/;
$m->set('a', 11);
print STDERR  $m->get('a'), $/;
print STDERR  $m->get('b'), $/;
