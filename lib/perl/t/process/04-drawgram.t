#!/usr/bin/perl
use strict;
use warnings;

#use Test::More tests => 1;                      # last test to print
use Test::More 'no_plan';

use FindBin;

BEGIN {
	use_ok('DNALC::Pipeline::Process::Phylip::DrawGram');
}

my $intree = "$FindBin::Bin/phy-drawgram-input.nw";

my $d = DNALC::Pipeline::Process::Phylip::DrawGram->new("$FindBin::Bin");
ok(-x $d->{conf}->{program}, "DrawGram binary exists");

my $rc = $d->run(input => $intree, debug => 1);
ok(0 == $rc, "DrawGram exit code = 0(success)");

my $ps_output = $d->get_output;
is($ps_output, "$FindBin::Bin/PHY_DRAWGRAM/plotfile", "Got output in PS format.");

#cleanup
#for (<$FindBin::Bin/MUSCLE/*>)
#{
#	unlink $_;
#}
#rmdir "$FindBin::Bin/MUSCLE";
