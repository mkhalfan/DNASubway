#!/usr/bin/perl -w
use strict;

# Import GFF into JBrowse

use constant JB     => '/usr/local/tomcat7/webapps/WebApollo/jbrowse';

chdir JB || die "I could not cd to ".JB." $!";

while (my $source = shift) {
    print STDERR "$0: I am deleting the old JBrowse track $source!\n";
    my $cmd = "bin/remove-track.pl --trackLabel $source --quiet";
    my $source_fs = "data/tracks/$source";
    if (-d $source_fs) {
	system "rm -fr $source_fs";
    }
    system $cmd;
}

