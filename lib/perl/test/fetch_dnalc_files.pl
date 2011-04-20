#!/usr/bin/perl 

use common::sense;
use HTTP::Tiny ();
use JSON::XS qw(decode_json);
use DNALC::Pipeline::Utils qw/random_string/;
use Data::Dumper;

my @flist = ();
#my @flist = (523, 524, 525, 526);
my $srv = 'http://dnalc02.cshl.edu/genewiz/files?o=24;f=' . join(',', @flist);

my $ht = HTTP::Tiny->new(timeout => 30 );
my $response = $ht->get($srv);

if ($response->{success} && length $response->{content}) {
	#my $coder = JSON::XS->new;
	my $data = eval { decode_json($response->{content}); };
	print STDERR Dumper( $data ), $/;
	my $dir = "/tmp/" . random_string(4, 8);
	mkdir $dir;
	if ($data && 'ARRAY' eq ref $data) {
		for (@$data) {
			print $_->{id}, $/;
			my $file = my $url = $_->{file};
			$file =~ s/^.*\///;
			$file = $dir . '/' . $file;
			print $url, $/;
			print $file, $/;
			$ht->mirror($url, $file);
		}
	}

	#print "$response->{status} $response->{reason}\n";
}
#print $response->{content} if length $response->{content};
