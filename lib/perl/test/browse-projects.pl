#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  browse.pl
#
#        USAGE:  ./browse.pl  
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
#      CREATED:  08/03/10 08:51:29
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Data::Dumper;
use DNALC::Pipeline::MasterProject;

#my @mp = DNALC::Pipeline::MasterProject->get_sorted({
#					order_by => 'u.name_last desc',
#				});

my $pager = DNALC::Pipeline::MasterProject->pager(5, 2);
my @mp = $pager->get_public_sorted({
	   order_by => 'u.name_last desc',
	});
print Dumper( $mp[1]), $/;
for (@mp) {
	print $_->id, " ", $_->{full_name}, $/;
}
print STDERR  "-------------", $/;

# filter by user_id
@mp = $pager->get_mine_sorted({
	   user_id => 90,
	   order_by => 'u.name_last ASC'
	});
for (@mp) {
	print $_->id, " ", $_->{full_name}, $/;
}
print STDERR  "-------------", $/;


#filter by user's name
@mp = $pager->get_public_sorted({
	   order_by => 'u.name_last ASC',
	   where => { title => 'auto', user_name => 'Gbzdpy'},
	});
for (@mp) {
	print $_->id, " ", $_->{full_name}, "\t", $_->{organism},$/;
}
print STDERR  "-------------", $/;


