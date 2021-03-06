#!/usr/bin/perl -w
use strict;
use Data::Dumper;

# Import GFF into JBrowse

use constant JBPATH => '/usr/local/tomcat7/webapps/project';
use constant IMPORT => 'bin/flatfile-to-json.pl';


my $pid = shift;
my $jb_path = JBPATH . "/$pid/jbrowse";
chdir $jb_path || die "I could not cd to $jb_path";

my $infile = shift || die "I need a GFF3 infile! $!";
-f $infile || die "The infile $infile does not exist! $!";

my ($source) = $infile =~ /([^\.]+)\.gff3/;
my $track_path = "data/tracks/$source";


my %nice_name = (
		 FGENESH   => 'FGenesH',
   		 AUGUSTUS  => 'Augustus',
		 SNAP      => 'SNAP',
		 TRNA_SCAN => 'tRNA Scan',
		 REPEAT_MASKER => 'RepeatMasker',
		 BLASTN => 'Blastn',
		 BLASTX => 'Blastx'
		 );

my @args;
if ($source =~ /AUGUSTUS|FGENESH|SNAP/) {
    push @args, (
		 '--gff' => $infile,
		 '--getSubfeatures',
		 '--type' => 'mRNA',
		 '--trackLabel' => $source,
		 '--key' => $nice_name{$source}
		 );
}
else {
    push @args, (
		 '--gff' => $infile,
		 '--getSubfeatures',
		 '--arrowheadClass' => 'null',
		 '--trackLabel' => $source,
		 '--key' => "\'User $nice_name{$source}\'"
		 );
}

#print STDERR "$0 ARGS: ", Dumper \@args;
my $importer = IMPORT;
print STDERR "importing $source\n";
my $cmd = "$importer @args";
print STDERR "Running: $cmd\n";
system $cmd;


