#!/usr/bin/perl -w
use strict;

# Load either WebApollo or plain old JBrowse config

use constant JB     => '/usr/local/tomcat7/webapps/project';

my $pid = shift;
my $apollo = shift;

my $path = JB . "/$pid/jbrowse/data";
chdir $path or die "could not cd to $path:$!";

my $target = $apollo ? 'apollo.json' : 'jbrowse.json';

system "cp $target trackList.json";



