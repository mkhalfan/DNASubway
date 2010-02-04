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

use Net::Telnet::Gearman;
use Data::Dumper;

my $session = Net::Telnet::Gearman->new(
	Host => '127.0.0.1',
	Port => 7003,
);

my @workers   = $session->workers();
print STDERR Dumper( \@workers), $/;
#my @functions = $session->status();
#print STDERR Dumper( \@functions), $/;
#my $version   = $session->versioI#n();

my $result    = $session->maxqueue( routines_check_stop_if => 10 );
print STDERR  "Set maxque for routines_check_stop_if to 10: ", $result, $/;

$result    = $session->maxqueue( routines_worker_exit => 10 );
print STDERR  "Set maxque for routines_worker_exit to 10: ", $result, $/;

