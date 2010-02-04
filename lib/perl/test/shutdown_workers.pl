#!/usr/bin/perl -w

use strict;
use Gearman::Client ();
use Data::Dumper;
use Storable qw/thaw freeze/;
use Net::Telnet::Gearman;


my $session = Net::Telnet::Gearman->new(
	Host => '127.0.0.1',
	Port => 7003,
);

#my @workers   = $session->workers();
#print STDERR Dumper( \@workers), $/;
#my @functions = $session->status();

#my $result    = $session->maxqueue( routines_check_stop_if => 10 );
#print STDERR  "Set maxque for routines_check_stop_if to 10: ", $result, $/;

my $client = Gearman::Client->new;
my $sx = $client->job_servers('127.0.0.1');

my $x;
if (0) {
	$x = $client->do_task( 'apollo_check_stop_if' );
	if ($@) {
		print STDERR  "Errors: $!", $/;
	}
	else {
		print STDERR  "Apollo status: ";
		print STDERR  Dumper(thaw $$x), $/;
	}
}

#print STDERR  '--------------------------', $/;
$client->do_task( 'apollo_worker_exit' );
print STDERR  '--------------------------', $/;

#$x = $client->do_task( 'routines_check_stop_if' );
#print STDERR  "Routines status: ";
#print STDERR  Dumper(thaw $$x), $/;

$client->do_task( 'routines_worker_exit' );
#print STDERR  '--------------------------', $/;

__END__
$x = $client->do_task( fgenesh => '/var/www/vhosts/pipeline.dnalc.org/var/projects/0035');
print STDERR  Dumper(thaw $$x), $/;


