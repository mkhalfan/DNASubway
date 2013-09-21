#!/usr/bin/perl -w
use strict;

use lib '/var/www/lib/perl';
use DNALC::Pipeline::Config;
use Data::Dumper;


my $pid      = shift or die "I need at least a project id!";
my $organism = shift or die "I also need a species_name!";
$organism = lc $organism;
$organism =~ /^[a-z]+_[a-z]+$/ 
    or die "Organism name ($organism) is not formatted correctly!";

my $config = DNALC::Pipeline::Config->new->cf->('WEB_APOLLO');
my $webapp_path = $config->cf->{'WEBAPP_PATH'};
my $web_apollo_base = "$webapp_path/species.tar.gz";

# First, we unpack the web_apollo directory tree (with symlinks)
my $target_dir = "$webapp_path/$pid";
mkdir $target_dir or die $!;
chdir $target_dir or die $!;
system "tar zxvf $web_apollo_base";

# Set up permissions so WebApollo/tomcat can save annotations 
system "chmod 777 tmp annotations";

# Interpolate variables in config.xml
chdir 'config' or die $!;
open IN,  'config.base.xml' or die $!;
open OUT, '>config.xml' or die $!;

while (<IN>) {
   s/WEBAPP_PATH/$webapp_path/;
   s/PROJECT_ID/$pid/;
   s/ORGANISM/$organism/;
   print OUT;
}
close IN;
close OUT;

exit 0;
