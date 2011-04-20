#!/usr/lib/perl -w

use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use strict;
use DNALC::Pipeline::Utils qw/random_string/;
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
my $dir = "/tmp/" . random_string(4, 8);
mkdir $dir;
my $arguments = nfreeze( {
			o => 24, 
			ids => [523, 524, 525, 526],
			dir => $dir,
		});

#my $rc = $client->do_task( dnalc_files =>  $arguments);
#$rc = thaw($$rc);
#print STDERR  "xx = ", Dumper( $rc), $/;

my $h = $client->dispatch_background( dnalc_files => $arguments );
print STDERR  "dir = ", $dir, $/;
print STDERR  "h = ", $h, $/;

my $tries = 21;
while ($tries--) {
	sleep 1;
	my $status = $client->get_status($h);
	print STDERR Dumper($status), $/;
	print STDERR 'Known = ', $status->known, $/;
	print STDERR 'Running = ', $status->running, $/;
	last unless ($status->known || $status->running);
	#print STDERR 'Progress = ', $status->progress, $/;
	print STDERR 'Percent = ', sprintf("%2.2f", ($status->percent || 0) * 100), $/;# if $status->running;
	print STDERR  "-----------------------------", $/;

}


