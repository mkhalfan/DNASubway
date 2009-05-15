#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  gearman-status.pl
#
#        USAGE:  ./gearman-status.pl  
#
#  DESCRIPTION:  
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  05/13/09 21:50:15
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Net::Telnet ();

my $t = new Net::Telnet (Timeout => 5, Host => 'localhost', Port => 7003 );
my $ok = $t->print('status');
if ($ok) {
	while (my $line = $t->getline ) {
		chop $line;
		last if $line =~ /^\./;
		print "got line: [", $line, "]", $/;
	}
}
$t->close;


