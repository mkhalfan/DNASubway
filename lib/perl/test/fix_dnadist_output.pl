#!/usr/bin/perl -w

use common::sense;
use IO::File ();

my $in = $ARGV[0];

#print $in, $/;

fix_it($in, 30);

sub fix_it {
	my ($in, $name_length) = @_;
	return unless $in;

	my $in_fixed = $in . "_fixed";
	my $fhi = IO::File->new($in);
	return unless $fhi;

	my $format = "0${name_length}%s";

	# read 1st two lines from the file
	my $l = <$fhi>;
	$l = <$fhi>;
	if ($l && $l =~ /^(\S.*\s*)$/) {
		chomp $l;
		if ($name_length == length $l) {
			return;
		}
	}

	$fhi->seek;
	my $fho = IO::File->new("> $in_fixed");
	return unless $fho;

	while (my $l = <$fhi>) {
		chomp $l;
		if ($l =~ /^(\S.*\s*)$/) {
			last if length $l == $name_length;

			my @x = split /\s+/, $l;
			$x[0] = sprintf("%-${name_length}s", $x[0]);
			print $fho "@x", "\n";
		}
		else {
			print $fho $l, "\n";
		}
	}
	$fhi->close;
	$fho->close;

	print "fixed: ", $in_fixed, " ", -s $in_fixed, $/;
}
