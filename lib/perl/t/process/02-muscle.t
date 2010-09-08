#!/usr/bin/perl
use strict;
use warnings;

#use Test::More tests => 1;                      # last test to print
use Test::More 'no_plan';

use FindBin;

BEGIN {
	use_ok('DNALC::Pipeline::Process::Muscle');
}

my $muscle_input = "$FindBin::Bin/muscle_input.fasta";

my $m = DNALC::Pipeline::Process::Muscle->new("$FindBin::Bin");
ok(-x $m->{conf}->{program}, "Muscle binary exists");

my $rc = $m->run(input => $muscle_input, debug => 1);
ok(0 == $rc, "Muscle exit code = 0(success)");

my $aln_file = $m->get_output('fasta');
is($aln_file, "$FindBin::Bin/MUSCLE/output.fasta", "Got output in fasta format.");

#cleanup
#for (<$FindBin::Bin/MUSCLE/*>)
#{
#	unlink $_;
#}
#rmdir "$FindBin::Bin/MUSCLE";
