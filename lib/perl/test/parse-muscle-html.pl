#!/usr/bin/perl 

use common::sense;
use IO::File ();

my $file = 'muscleout.html';

my $fh = IO::File->new;
if ($fh->open($file)) {
	
	my $pre = 0;
	my $groups = 0;
	my @seq = ();
	my @ids = ();
	my $cnt = 0;
	while (<$fh>) {
		
		if ($_ =~ /^\<\/?PRE\>/) {
			$pre = !$pre;
			next;
		}
		next unless $pre;
		#next if $groups;
		if ($_ =~ /^$/) {
			$groups++;
			$cnt = 0;
			next;
		}
		
		my ($id, $html_snippet) = ($_ =~ /^\<SPAN STYLE="background-color:#FFEEE0"\>(.*?)\s+(\<SPAN.*)$/);
		$html_snippet =~ s|<SPAN STYLE="background-color:#FFFFFF"></SPAN>||;
		unless ($groups) {	
			push @ids, $id;
			push @seq, $html_snippet . "</span>";
			#print "[$id]", $/;
		}
		else {
			$seq[$cnt++] .= $html_snippet . "</span>";
		}
	}
	
	$fh->close;
		
	#print "groups = $groups\n";
	#print "Done\n";
	#print "@ids", $/;
	#print $seq[0];
	print "<body><div>";
	print "<div id=\"seqids\" style=\"float:left; width: 50px;\"><pre>";
	for (@ids) {
		print $_, $/;
	}
	print "</pre></div>";
	print "<div id=\"seqids\" style=\"float:right;width:1000px;overflow-y:hidden\"><pre>";
	for (@seq) {
		print $_, $/;
	}
	print "</pre></div>";
	print "</div></body>";
}