#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 12;                      # last test to print
#use Test::More 'no_plan';

use FindBin;
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Process::Phylip::SeqBoot ();
use DNALC::Pipeline::Process::Phylip::DNADist ();
use DNALC::Pipeline::Process::Phylip::Neighbor ();
use DNALC::Pipeline::Process::Phylip::Consense ();

use File::Copy 'cp';
#---------------------------------------------------


BEGIN {
	use_ok('DNALC::Pipeline::Process::Phylip::DNADist');
	use_ok('DNALC::Pipeline::Process::Phylip::SeqBoot');
	use_ok('DNALC::Pipeline::Process::Phylip::Neighbor');
	use_ok('DNALC::Pipeline::Process::Phylip::Consense');
}

my $input = "$FindBin::Bin/tree_bootstrapping_input.txt";
my $pwd = "/tmp";

my $s = DNALC::Pipeline::Process::Phylip::SeqBoot->new($pwd);
ok(-x $s->{conf}->{program}, "SeqBoot binary exists");

my $rc = $s->run(input => $input);
ok(0 == $rc, "SeqBoot exit code = 0(success)");

#----------------------------------
$input = $s->get_output;

my $d = DNALC::Pipeline::Process::Phylip::DNADist->new($pwd);
ok(-x $d->{conf}->{program}, "DNADist binary exists");

$d->run(input => $input, debug => 0, bootstrap => 1);
ok(0 == $d->{exit_status}, "DNADist exit code = 0(success)");

#----------------------------------
$input = $d->get_output;

my $n = DNALC::Pipeline::Process::Phylip::Neighbor->new($pwd);
ok(-x $n->{conf}->{program}, "Neighbor binary exists");

$n->run(input => $input, debug => 0, bootstrap => 1);
ok(0 == $n->{exit_status}, "Neighbor exit code = 0(success)");

#----------------------------------
$input = $n->get_tree;

my $c = DNALC::Pipeline::Process::Phylip::Consense->new($pwd);
ok(-x $c->{conf}->{program}, "Neighbor binary exists");

$c->run(input => $input, debug => 0);
ok(0 == $c->{exit_status}, "Consense exit code = 0(success)");


