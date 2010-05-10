#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::Config();
use IO::File ();
use File::Basename;
use Gearman::Client ();
use Net::Telnet::Gearman;
use Data::Dumper;

#--------------
my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $host = $pcf->{GEARMAN_SERVERS} && 'ARRAY' eq ref $pcf->{GEARMAN_SERVERS}
				? $pcf->{GEARMAN_SERVERS}->[0]
				: '127.0.0.1:7003';
my ($ip, $port) = split /:/, $host;

my $gsession = Net::Telnet::Gearman->new(
	Host => $ip,
	Port => $port || 7003,
);

my $gclient = Gearman::Client->new;
$gclient->job_servers(@{$pcf->{GEARMAN_SERVERS}});

print STDERR  "Maybe we shoud check if we already have 'exit' function in the queue.", $/;

my %gearman_functions = map {$_->name => $_->running} $gsession->status();
#print STDERR Dumper( \%gearman_functions), $/;
my $gearman_config_file = '/etc/sysconfig/gearman';
#--------------

sub print_stats {

	my @functions = $gsession->status;
	last unless @functions;
	print STDERR  "----------------", $/;
	print STDERR  "name\t# running", $/;
	for (@functions) {
		print STDERR  $_->name, "\tR=", $_->running, "\tB=", $_->busy, $/;
	}
}


print_stats();

my %gearman_config = ();
my %exit_functions = ();

my $fh = IO::File->new;
if ($fh->open($gearman_config_file)) {
	while(<$fh>) {
		chomp;
		next if ($_ =~ /^$/ || $_ =~ /^#/);
		if ($_ =~ /.+=.+/) {
			my ($k, $v) = split /=/, $_;
			$v =~ s/["']//g;
			$gearman_config{$k} = $v;
		}
	}
}
my @tmp = split /\s+/, $gearman_config{WORKERS};
#print STDERR Dumper( \@tmp ), $/;
if (!@tmp || scalar (@tmp) % 2 != 0) {
	print STDERR "Wrong data in WORKERS variable..\n", $/;
	exit 1;
}

for (my $i = 0; $i < scalar @tmp; $i += 2) {
	my $script_name = fileparse($tmp[$i+1]);
	$script_name =~ s/\.[^.]*$//;

	my $fname = $script_name . '_exit';
	if (exists $gearman_functions{ $fname } ) {
		print STDERR  "[$script_name]:", $/;
		# send the appropriate number of '_exit' commands for this worker
		for (1 .. $gearman_functions{ $fname }) {
			my $h = $gclient->dispatch_background( $fname );
			#print STDERR  "\tLaunched [$fname], h = ", $h, $/;
		}
		print STDERR  "\tsent ", $gearman_functions{ $fname }, " 'exit' jobs.\n";
	}
}

while (1) {
	print_stats();
	sleep 5;
}

