#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  logger.pl
#
#        USAGE:  ./logger.pl  
#
#  DESCRIPTION:  u
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  09/03/10 12:06:02
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use DNALC::Pipeline::Log;
use Data::Dumper;

my $log = DNALC::Pipeline::Log->new('test/loger.conf');

#DNALC::Pipeline::Log->init('test/loger.conf');
#my $log = DNALC::Pipeline::Log->new;

#print STDERR Dumper( $log), $/;
$log->info("hmmmm");
$log->emergency("hmmmm");
