#!/usr/bin/perl -w
use strict;


# massage GFF to be suitable for display in JBrowse/WebApollo

my $offset = shift;
$offset && $offset + 1 > 1 || die "First argument (offset) must be a number";
my $chr    = shift || die "I need a second argument";
die "second argument (refseq) must be a string (not a file)" if -f $chr;

$chr =~ s/chr//i;

while (my $line = <>) {
    #next if $line =~ /^##gff/;
    next if $line =~ /^#/;
    $line =~ s/transcript/mRNA/; # WebApollo, ever heard of a coding gene?
    my @gff = split("\t",$line);
    @gff > 7 || die "ERROR at jb_gff_export.pl: malformed GFF";
    next unless @gff == 9;
    next if $gff[2] eq 'chromosome';

    $gff[0] = $chr;
   # unless ($gff[1] eq 'WebApollo') {
    if ($gff[1] eq 'SNAP' || $gff[1] eq 'AUGUSTUS' || $gff[1] eq 'BLASTN' || $gff[1] eq 'BLASTX' || $gff[1] eq 'FGenesH' || $gff[1] eq 'RepeatMasker'){
	$gff[3] += $offset;
	$gff[4] += $offset;
    }

    if ($gff[2] eq 'mRNA') {
	$gff[8] =~ s/ID=([^;]+)/ID=$1;Name=$gff[1]-$1/;
    }

    #print STDERR join("\t",@gff);
    print join("\t",@gff);
}
