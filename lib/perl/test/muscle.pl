#!/usr/bin/perl 

use strict;
use DNALC::Pipeline::Process::Muscle();
use Data::Dumper;

my $m = DNALC::Pipeline::Process::Muscle->new('/tmp');

my $st = $m->run(pretend=>0, debug => 0, input => '/home/cornel/sample_rbcL_data.fas');
#print STDERR Dumper( $m ), $/;
print STDERR  "exit_status: ", $m->{exit_status}, $/;
print STDERR  "elapsed: ", $m->{elapsed}, $/;

print STDERR "Fasta out: ", $m->get_output, $/;
print STDERR "html out: ", $m->get_output('html'), $/;

