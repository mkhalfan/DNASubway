#!/usr/bin/perl -w
use strict;


use constant PATH => '/var/www/vhosts/pipeline.dnalc.org/var/webapps/project';

my $pid      = shift or die "I need at least a project id!";
#my $organism = shift or die "I also need a species_name!";
#$organism = lc $organism;
#$organism =~ /^[a-z]+_[a-z]+$/ 
#    or die "Organism name ($organism) is not formatted correctly!";
my $webapp_path = shift;
#my $web_apollo_base = "$webapp_path/species.tar.gz";


print STDERR "WEB_APOLLO $ENV{USER} $organism $pid\n";


# First, we unpack the web_apollo directory tree (with symlinks)
my $target_dir = "$webapp_path/project/$pid";
mkdir $target_dir or die "Could not creat target $target_dir:$!";
chdir $target_dir or die "Could not cd to $target_dir:$!";
system "tar zxvf $web_apollo_base";

# Set up permissions so WebApollo/tomcat can save annotations 
system "chmod 777 tmp annotations";

# Interpolate variables in config.xml
chdir 'config' or die $!;
open IN,  'config.base.xml' or die $!;
open OUT, '>config.xml' or die $!;

while (<IN>) {
   s/WEBAPP_PATH/$target_dir/;
   s/PROJECT_ID/$pid/;
   s/ORGANISM/$organism/;
   print OUT;
}
close IN;
close OUT;

print STDERR "Created WebApollo instance at $target_dir\n";

exit 0;
