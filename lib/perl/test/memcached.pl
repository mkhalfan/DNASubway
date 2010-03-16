#!/usr/bin/perl

use strict;

use DNALC::Pipeline::CacheMemcached ();
use Data::Dumper;

my $m = DNALC::Pipeline::CacheMemcached->new;

#print STDERR Dumper( $m), $/;
#$mc->set('b', 12);
#print STDERR  $mc->get('b'), $/;
my $a = $m->get('a');
unless ($a) {
	$m->set('a', 11);
	$a = 11;
}
else {
	$m->set('a', $a+1);
}
print STDERR  $m->get('a'), $/;
