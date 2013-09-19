#!/usr/bin/perl -w
use strict;


# massage GFF to be suitable for display in JBrowse/WebApollo

my $offset = shift;
$offset && $offset + 1 > 1 || die "First argument (offset) must be a number";
my $chr    = shift || die "I need a second argument";
die "second argument (refseq) must be a string (not a file)" if -f $chr;

$chr =~ s/chr//i;

while (my $line = <>) {
    next if $line =~ /^##gff/;
    my @gff = split("\t",$line);
    next unless @gff == 9;
    next if $gff[2] eq 'chromosome';
    $gff[0] = $chr;
    $gff[3] += $offset;
    $gff[4] += $offset;
    print join("\t",@gff);
}
