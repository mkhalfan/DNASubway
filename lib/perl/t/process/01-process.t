#
#===============================================================================
#
#         FILE:  01-process.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  08/30/10 14:17:27
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

#use Test::More tests => 1;                      # last test to print
use Test::More 'no_plan';

BEGIN { use_ok( 'DNALC::Pipeline::Process' ); }
#diag("Can't load module DNALC::Pipeline::Process\n");

