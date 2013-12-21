#!/usr/bin/perl -w
use strict;
use Data::Dumper;

use lib '/var/www/lib/perl';
use DNALC::Pipeline::Config;

# Import GFF into JBrowse

use constant JBPATH => '/usr/local/tomcat7/webapps/project';
use constant IMPORT => 'bin/flatfile-to-json.pl';

my $pid = shift;
my $jb_path = JBPATH . "/$pid/jbrowse";
chdir $jb_path || die "I could not cd to $jb_path";

my $infile = shift || die "I need a GFF3 infile! $!";
-f $infile || die "The infile $infile does not exist! $!";
print STDERR "INFILE: $infile \n";
my ($source) = $infile =~ /([^\.]+)\.gff3/;
my $track_path = "data/tracks/$source";

my $wconfig = DNALC::Pipeline::Config->new->cf('WEB_APOLLO');
my $extra_args = $wconfig->{extra_args};
my $nice_names = $wconfig->{nice_names};

my @args;
if ($source =~ /AUGUSTUS|FGENESH|SNAP|APOLLO|USER_GFF/) {
print STDERR "FROM IMPORTER: source: $source\n";
    @args = (
		 '--gff' => $infile,
		 '--getSubfeatures',
		 '--type' => 'mRNA',
		 '--trackLabel' => $source,
		 '--key' => $$nice_names{$source},
	         $$extra_args{$source}
		 );
}
else {
    @args = (
		 '--gff' => $infile,
		 '--getSubfeatures',
		 '--trackLabel' => $source,
		 '--key' => qq('$$nice_names{$source}'),
	         $$extra_args{$source}
		 );
}

#print STDERR "$0 ARGS: ", Dumper \@args;
my $importer = IMPORT;
#print STDERR "importing $source\n";
my $cmd = "$importer @args";
#print STDERR "Running: $cmd\n";
system $cmd;


