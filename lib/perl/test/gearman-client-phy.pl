#!/usr/lib/perl -w

use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use strict;
use DNALC::Pipeline::Config();
use Gearman::Client ();
use Data::Dumper;
use Storable qw/thaw nfreeze/;

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $client = Gearman::Client->new;
my $sx = $client->job_servers(@{$pcf->{GEARMAN_SERVERS}});

#my $h = $client->dispatch_background( augustus => 98 );
#print STDERR  "h = ", $h, $/;
#print STDERR  '--------------------------', $/;

#----
my $arguments = nfreeze( {pid => 100, xxx => 200});
#print STDERR  $arguments , $/;
my $rc = $client->do_task( "phy_alignment" =>  $arguments);
$rc = thaw($$rc);
#print STDERR  "xx = ", Dumper( thaw($xx)), $/;
print STDERR  "status = ", $rc->{status}, $/;


#----
$arguments = nfreeze( {pid => 100});
$rc = $client->do_task( "phy_tree" =>  $arguments);
$rc = thaw($$rc);
print STDERR  "status = ", $rc->{status}, $/;

