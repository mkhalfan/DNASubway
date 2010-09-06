#!/usr/bin/perl

use strict;
use Data::Dumper;

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Process::Phylip ();

#my $cf = DNALC::Pipeline::Config->new->cf('PHY_NEIGHBOR');
my $p = DNALC::Pipeline::Process::Phylip->new('/tmp');

$p->run(input => '/tmp/infile', 
		pretend => 0, 
		debug => 1
	);
print STDERR  "exit_status: ", $p->{exit_status}, $/;
print STDERR  "elapsed: ", $p->{elapsed}, $/;
print STDERR  "tree: ", $p->get_tree, $/;


#print STDERR Dumper( $p ), $/;
