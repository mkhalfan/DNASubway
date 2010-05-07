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

use DNALC::Pipeline::Config();
use Net::Telnet::Gearman;
use Data::Dumper;

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $host = $pcf->{GEARMAN_SERVERS} && 'ARRAY' eq ref $pcf->{GEARMAN_SERVERS}
				? $pcf->{GEARMAN_SERVERS}->[0]
				: '127.0.0.1:7003';
my ($ip, $port) = split /:/, $host;

my $session = Net::Telnet::Gearman->new(
	Host => $ip,
	Port => $port || 7003,
);

my @workers   = $session->workers();
my @functions = $session->status();
print STDERR  scalar(@workers), $/;
print STDERR  scalar(@functions), $/;
#print STDERR Dumper( \@workers), $/;
#print STDERR Dumper( \@functions), $/;
#my $version   = $session->versioI#n();

for (@functions) {
	print $_->name, ' ', $_->running, $/;
}
__END__
my $result    = $session->maxqueue( routines_check_stop_if => 10 );
print STDERR  "Set maxque for routines_check_stop_if to 10: ", $result, $/;

$result    = $session->maxqueue( routines_worker_exit => 10 );
print STDERR  "Set maxque for routines_worker_exit to 10: ", $result, $/;

