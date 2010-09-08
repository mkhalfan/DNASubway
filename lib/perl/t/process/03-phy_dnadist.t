#!/usr/bin/perl
use strict;
use warnings;

#use Test::More tests => 1;                      # last test to print
use Test::More 'no_plan';

use FindBin;

BEGIN {
	use_ok('DNALC::Pipeline::Process::Phylip::DNADist');
}

my $phy_dnadist_input = "$FindBin::Bin/phy_neighbor_input1.phys";

my $m = DNALC::Pipeline::Process::Phylip::DNADist->new("$FindBin::Bin");
ok(-x $m->{conf}->{program}, "DNADist binary exists");


my $rc = $m->run(input => $phy_dnadist_input, debug => 0);
ok(0 == $rc, "Neighbor exit code = 0(success)");

my $tree_file = $m->get_output;
#note($tree_file);
is($tree_file, "$FindBin::Bin/PHY_DNADIST/outfile", "Got the tree in newick format.");

#cleanup
#for (<$FindBin::Bin/PHY_DNADIST/*>)
#{
#	print $_, $/;
#	unlink $_;
#}
#rmdir "$FindBin::Bin/PHY_NEIGHBOR";

