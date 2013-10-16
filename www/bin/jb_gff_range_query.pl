#!/usr/bin/perl -w
use strict;
use Bio::Range;

# extract only the desired segment from a GFF file
# we assume the ref seq name and coordinates in the GFF file
# are correct

my $gff_file = shift or die usage();
-f $gff_file or die usage("There GFF file $gff_file does not exist");

my $ref   = shift;
my $start = shift;
my $end   = shift;
$ref && $start && $end || die usage();


# Create the target range
# give us a bit of padding
$start -= 1000;
$end   += 1000;
$start  = 1 if $start < 1;
my $target_range = Bio::Range->new(-start=>$start, -end=>$end);

open GFF, $gff_file or die $!;
while (<GFF>) {
    next if /^#/;
    my @gff = split;

    $gff[0] eq $ref || next;

    my $range = Bio::Range->new(-start=>$gff[3], -end=>$gff[4]);

    next unless $range->overlaps($target_range);

    print;
}


sub usage {
    my $msg = shift;
    $msg .= "\nUsage: /var/www/bin/jb_gff_range_query.pl gff_file ref start end\n";
}
