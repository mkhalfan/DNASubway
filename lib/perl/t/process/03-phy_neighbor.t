#!/usr/bin/perl
use strict;
use warnings;

#use Test::More tests => 1;                      # last test to print
use Test::More 'no_plan';

use FindBin;

BEGIN {
	use_ok('DNALC::Pipeline::Process::Phylip::Neighbor');
}

my $phy_neighbor_input = "$FindBin::Bin/phy_neighbor_input1.phys";

my $m = DNALC::Pipeline::Process::Phylip::Neighbor->new("$FindBin::Bin");
ok(-x $m->{conf}->{program}, "Neighbor binary exists");

my $rc = $m->run(input => $phy_neighbor_input, debug => 0);
ok(0 == $rc, "Running on alignment, Neighbor exit code = 0(success)");

my $tree_file = $m->get_tree;
#note($tree_file);
is($tree_file, "$FindBin::Bin/PHY_NEIGHBOR/outtree", "Got the tree in newick format.");

#cleanup
for (<$FindBin::Bin/PHY_NEIGHBOR/*>)
{
	#print $_, $/;
	unlink $_;
}

my $phy_dist_matrix = "$FindBin::Bin/phy_neighbor_dist_matrix.phys";

$rc = $m->run(input => $phy_dist_matrix, debug => 0);
ok(0 == $rc, "Running on dist matrix, Neighbor exit code = 0(success)");

$tree_file = $m->get_tree;
#note($tree_file);
is($tree_file, "$FindBin::Bin/PHY_NEIGHBOR/outtree", "Got the tree in newick format.");



