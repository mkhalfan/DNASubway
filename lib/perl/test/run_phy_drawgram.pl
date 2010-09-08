#!/usr/bin/perl

use strict;
use Data::Dumper;
use FindBin;

use DNALC::Pipeline::Process::Phylip::DrawGram ();

my $p = DNALC::Pipeline::Process::Phylip::DrawGram->new("/tmp");

my $file = "$FindBin::Bin/../t/process/phy_drawgram_input1.nw";
print STDERR  $file, $/;
$p->run(input => $file, 
		pretend => 0, 
		debug => 1
	);
print STDERR  "exit_status: ", $p->{exit_status}, $/;
exit 1 if $p->{exit_status};
print STDERR  "elapsed: ", $p->{elapsed}, $/;
print STDERR  "plotfile: ", $p->get_output, $/;


print STDERR Dumper( $p ), $/;
