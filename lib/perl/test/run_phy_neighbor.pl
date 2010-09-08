#!/usr/bin/perl

use strict;
use Data::Dumper;

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Process::Phylip::Neighbor ();

my $p = DNALC::Pipeline::Process::Phylip::Neighbor->new('/tmp');

$p->run(input => '/tmp/infile', 
		pretend => 0, 
		debug => 1
	);
print STDERR  "exit_status: ", $p->{exit_status}, $/;
print STDERR  "elapsed: ", $p->{elapsed}, $/;
print STDERR  "tree: ", $p->get_tree, $/;


#print STDERR Dumper( $p ), $/;
