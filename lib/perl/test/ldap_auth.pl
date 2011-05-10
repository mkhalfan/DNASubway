#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use DNALC::Pipeline::UserLDAP ();

my $u = {'u' => 'dnalcadmin', p => ''};
my $ok = DNALC::Pipeline::UserLDAP->auth( $u->{u}, $u->{p} );
print "ok: ", $ok || '0', $/;
$u = DNALC::Pipeline::UserLDAP->search($u->{u});
print Dumper($u), $/;
