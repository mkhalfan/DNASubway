#!/usr/bin/perl

use DNALC::Pipeline::Sample ();

my $samples = DNALC::Pipeline::Sample->retrieve_all;

#print STDERR  $samples, $/;
while (my $s = $samples->next) {
	print $s, $/;
	for my $l ($s->links) {
		next if $l->link_type;
		print "\t", $l, " ", $l->link_type, $/;
		$l->link_segment($s->segment);
		$l->link_start($s->start);
		$l->link_stop($s->stop);
		$l->link_type('gbrowse');
		$l->update;
	}
	#last;
}
