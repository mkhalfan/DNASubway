#!/usr/bin/perl

use strict;
use Data::Dumper;

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Process::Phylip::SeqBoot ();
use DNALC::Pipeline::Process::Phylip::DNADist ();
use DNALC::Pipeline::Process::Phylip::Neighbor ();
use DNALC::Pipeline::Process::Phylip::Consense ();

use File::Copy 'cp';
#---------------------------------------------------
my $pwd = "/tmp";

cp "t/process/tree_bootstrapping_input.txt", "$pwd/infile";

my $b = DNALC::Pipeline::Process::Phylip::SeqBoot->new($pwd);

$b->run(input => '/tmp/infile', debug => 1);
print STDERR  "exit_status: ", $b->{exit_status}, $/;
print STDERR  "elapsed: ", $b->{elapsed}, $/;
print STDERR  "output: ", $b->get_output, $/;

my $dnadist_input = $b->get_output;
unless (-f $dnadist_input) {
	die "Input for DNADIST is missing!";
}
#---------------------------------------------------
print STDERR  "-" x 20, $/;

my $d = DNALC::Pipeline::Process::Phylip::DNADist->new($pwd);
my $rc = $d->run(input => $dnadist_input, debug => 1, bootstrap => 1);

my $dist_file;
if ($rc == 0) {
	$dist_file = $d->get_output;
}
print STDERR  "DNADIST out file: ", $dist_file, $/;
#---------------------------------------------------
print STDERR  "-" x 20, $/;

my $p = DNALC::Pipeline::Process::Phylip::Neighbor->new($pwd);
$p->run(input => $dist_file, debug => 1, bootstrap => 1);
#print STDERR Dumper( $p ), $/;
print STDERR  "exit_status: ", $p->{exit_status}, $/;
print STDERR  "elapsed: ", $p->{elapsed}, $/;

my $multi_tree = $p->get_tree;
print STDERR  "mtree: ", $multi_tree, $/;

#---------------------------------------------------
print STDERR  "-" x 20, $/;

my $c = DNALC::Pipeline::Process::Phylip::Consense->new($pwd);
$c->run(input => $multi_tree, debug => 1);
print STDERR  "exit_status: ", $c->{exit_status}, $/;
print STDERR  "elapsed: ", $c->{elapsed}, $/;

my $tree = $c->get_tree;
print STDERR  "tree: ", $tree, $/;
