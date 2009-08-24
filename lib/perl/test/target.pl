#!/usr/bin/perl 

use strict;
use warnings;

use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;

my $ua = LWP::UserAgent->new;
$ua->agent("pipeline.dnalc.org");

my $res;
my $server = 'http://target.iplantcollaborative.org';
my $url = $server . '/ap_TARGeT_dna.php';

my $seq = q{TACTCCCTCCGGTTTCCTATTAGTTGTCGTTTAGGACAACGACACGGTCTCCAAAATATA
ACTTTGACCAATATTTTTTGTTAAAATACAAATGAACTCTTAATACATTTATACTTTTAT
AAAAGTACTTTTTATAACAAATTGGTGCATATAAATATTAGGTTCCAAAACTAAATAACA
AAATAGTTATTTGTAGTCAAAATTTTATAAGTTTGACTCGAACCTTATCCAAAACGACAA
CTAATAGGAAACCGGAGGGAGTA};

my $query = {
	'orgn[]' => [qw/At Zm3a/],
	'_querys_0' => $seq,
	'submit' => 'Tree'
};

my $xml_url;# = $server . '/Visitors/143_48_90_149/temp_0824144806.xml';

unless ($xml_url) {
	$res = $ua->post($url, $query);
	unless ($res->is_success) {
		print $res->status_line, "\n";
	}
	else {
		my $html = $res->content;
		#print "[$html]", $/;

		if ($html =~ /(\/Visitors.*\.xml)/s) {
			print $1, $/;
			$xml_url = $server . $1;
		}
	}
}

if ($xml_url) {
	#print $xml_url, $/;
	$res = $ua->get($xml_url);
	unless ($res->is_success) {
		print $res->status_line, "\n";
	}
	else {
		my $xml_str = $res->content;
		my $ref =  XMLin($xml_str);
		my $steps = $ref->{run}->{steps}->{step};
		if ($steps) {
			my ($nw_file) = grep {/\.nw$/} @{$steps->{Tree}->{program}->{output}};
			#print STDERR Dumper( $steps->{Tree}), $/;
			print "nw file = ", $nw_file, $/;
		}
		else {
			print "nema...\n";
		}
	}
}

