#!/usr/bin/perl -w
use strict;

use constant JB     => '/usr/local/tomcat7/webapps/WebApollo/jbrowse/data';

my $web_apollo = shift;

chdir JB;

my $target = $web_apollo ? 'apollo.json' : 'jbrowse.json';

system "cp $target trackList.json";



