#/usr/lib/perl -w

use strict;
use Gearman::Client ();
use Data::Dumper;
use Storable qw/thaw/;

my $client = Gearman::Client->new;
my $sx = $client->job_servers('127.0.0.1');

#my $h = $client->dispatch_background( augustus => '/var/www/vhosts/pipeline.dnalc.org/var/projects/0035' );
my $h = $client->dispatch_background( fgenesh => '/var/www/vhosts/pipeline.dnalc.org/var/projects/0035' );

print STDERR  "h = ", $h, $/;
print STDERR  '--------------------------', $/;

__END__

my $x = eval {
	$client->do_task( 
		repeat_masker => '/var/www/vhosts/pipeline.dnalc.org/var/projects/0035'
	);
};
if ($@) {
	print STDERR  "Errors: $!", $/;
}
else {
	print STDERR  Dumper(thaw $$x), $/;
}

print STDERR  '--------------------------', $/;

$x = $client->do_task( fgenesh => '/var/www/vhosts/pipeline.dnalc.org/var/projects/0035');
print STDERR  Dumper(thaw $$x), $/;

print STDERR  '--------------------------', $/;
my $tasks = $client->new_task_set;
my $handle = $tasks->add_task( trna_scan => "53,tran_scan", {
	on_complete => sub { my $out = thaw(${$_[0]}); print Dumper($out), "\n" }
});
$tasks->wait;

print STDERR  "-----------------------------", $/;
while (1) {
	my $status = $client->get_status($h);
	print STDERR 'Known = ', $status->known, $/;
	print STDERR 'Running = ', $status->running, $/;
	print STDERR  "-----------------------------", $/;
	last unless $status->running;
	sleep 5;
}
