#!/usr/bin/perl

use strict;

use DNALC::Pipeline::Phylogenetics::DataFile;
use DNALC::Pipeline::Phylogenetics::DataSequence;
use DNALC::Pipeline::Phylogenetics::PairSequence;
use DNALC::Pipeline::Phylogenetics::Pair;
use Data::Dumper;

# mismatches
my $wrong = 0;
my $total = 0;

my $pairs_analized = 0;
my $pairs_wrong = 0;
my $pairs_with_consensus_edited = 0;
my %projects = ();
my %mismatches_per_pair = ();

my $pairs = DNALC::Pipeline::Phylogenetics::Pair->retrieve_all;

while (my $pair = $pairs->next) {
	my $muscle_alignment = $pair->alignment;
	my $consensus_edited = $pair->consensus;
	next if $muscle_alignment eq "";

	my @alignment_line_1 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[0]));
	my @alignment_line_2 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[1]));
	my @alignment_line_3 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[2]));
	my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]); #Sequence 1
	my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]); #Sequence 2
	my ($display_name_3, $consensus) = ($alignment_line_3[0], $alignment_line_3[1]); #Consensus

	next if (!$consensus || !$seq1 || !$seq2 || length($seq1 ) != length($consensus));

	my @pair_seq = $pair->paired_sequences;
	#print STDERR Dumper( \@pair_seq), $/;
	next unless @pair_seq;
	next if $pair_seq[0]->strand eq $pair_seq[1]->strand;

	# @seq has the 2 DataSequence objects belonging to a pair
	my @seq = map {$_->seq_id} @pair_seq;

	my ($ds_id_1) = map {$_ && $_->id} grep { $_->display_id eq $display_name_1 } @seq;
	my ($ds_id_2) = map {$_ && $_->id} grep { $_->display_id eq $display_name_2 } @seq;

	my ($df_id_1) = map {$_ && $_->file_id} grep { $_->display_id eq $display_name_1 } @seq;
	my ($df_id_2) = map {$_ && $_->file_id} grep { $_->display_id eq $display_name_2 } @seq;

	my ($df_1_strand) = map {$_ && $_->strand} grep { $_ &&  $_->seq_id && $_->seq_id eq $ds_id_1} @pair_seq;
	my ($df_2_strand) = map {$_ && $_->strand} grep { $_ &&  $_->seq_id && $_->seq_id eq $ds_id_2} @pair_seq;
	#print "P$pair: ", $df_1_strand, "\t", $df_2_strand, $/;
	#print STDERR Dumper( @pair_seq ), $/ unless $df_1_strand;

	my $df1 = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($df_id_1);
	next unless $df1 && $df1->file_type eq "trace";

	my $df2 = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($df_id_2);
	next unless $df2 && $df2->file_type eq "trace";

	next if ($df1->has_low_q || $df2->has_low_q);

	my @qs1 = $df1->quality_values();
	if ($df_1_strand eq "R"){
		@qs1 = reverse @qs1;
	}
	my @qs2 = $df2->quality_values();
	if ($df_2_strand eq "R"){
		@qs2 = reverse @qs2;
	}
	next unless(@qs2 && @qs1);
	#print "$pair: ", length $seq1, "\t", scalar @qs1, $/;
	#print "$pair: ", length $seq1, "\t", scalar @qs2, $/;


	# check if sequences were trimmed
	if (my $trim_1 = DNALC::Pipeline::Phylogenetics::DataSequenceTrim->retrieve($ds_id_1)){
	    @qs1 = splice(@qs1, $trim_1->start_pos, $trim_1->end_pos - $trim_1->start_pos);
	}

	if (my $trim_2 = DNALC::Pipeline::Phylogenetics::DataSequenceTrim->retrieve($ds_id_2)){
	    @qs2 = splice(@qs2, $trim_2->start_pos, $trim_2->end_pos - $trim_2->start_pos);
	}

	#print length $seq1, ' == ', scalar @qs1, $/;
	#print length $seq2, ' == ', scalar @qs2, $/;
	#next;

	my $x = 0;
	foreach (split//, $seq1){
		if ($_ eq "-"){
			splice @qs1, $x, 0, "-1";
		}
		$x++;
	}

	my $y = 0;
	foreach (split//, $seq2){
		if ($_ eq "-"){
			splice @qs2, $y, 0, "-1";
		}
		$y++;
	}


	#print $display_name_1, ": ", join( " ", map {sprintf("%3d", $_)} @qs1), $/;
	#print $display_name_2, ": ", join( " ", map {sprintf("%3d", $_)} @qs2), $/;
	#print $display_name_1, ": ", join( " ", map {sprintf("%3s", $_)} split(//, $seq1)), $/;
	#print $display_name_2, ": ", join( " ", map {sprintf("%3s", $_)} split(//, $seq2)), $/;

	my @local_wrongs = ();
	my $local_mismatches = 0;

	for (my $i = 0; $i <= length($seq1); $i++){
		my $a = substr($seq1, $i, 1);
		my $b = substr($seq2, $i, 1);
		my $c = substr($consensus, $i, 1);

		if ($a ne "N" && $b ne "N"){
			next if ($a eq '-' || $b eq '-');
				if ($a ne $b){ # there is a mismatch
					#$total++;
					$local_mismatches++;
					if ($qs1[$i] > $qs2[$i]){
						if ( $a ne $c ){
							push @local_wrongs, $i;
							#print "Pos: $i \nA: $a \nB: $b \nC: $c \n  ";
							#print substr($consensus, $i-2, 5), $/;
						}
					}
					elsif($qs1[$i] < $qs2[$i]) { # $qs1[i] < $qs2[i]
						if ($b ne $c){
							push @local_wrongs, $i;
							#print "Pos: $i \nA: $a \nB: $b \nC: $c \n  ";
						}
					}
				}
		}
	}

	# skip pairs w/ more than 1% of mismatches
	#next if ($local_mismatches/length $consensus > 0.01);

	if (@local_wrongs) {
		# skip the alignments with more than 1% of wrong calls done my merger
		#next if (scalar (@local_wrongs)/length $consensus > 0.01);

		$wrong += @local_wrongs;
		$total += $local_mismatches;

		if ($consensus_edited ne $consensus) {
			unshift(@local_wrongs, '*');
			$pairs_with_consensus_edited++;
		}
		else {
			$pairs_wrong++;
		}
		push @{$projects{$pair->project_id}}, $pair->id . '['. join(',', @local_wrongs) . ']';
	}
	$mismatches_per_pair{ $local_mismatches }++;
	$pairs_analized++;

}

#for (keys %projects) {
#	print $_, "\t", join (", ", @{$projects{$_}}), $/;
#}

#print "\nC: ", join( " ", map {sprintf("%3s", $_)} split(//, $consensus)), $/;
print "--------- \n";
print "Analyzed pairs: ", $pairs_analized, "\n";
print "Pairs w/ consensus that needed edited: ", $pairs_wrong, $/;
print "Pairs w/ consensus edited: ", $pairs_with_consensus_edited, sprintf(" (%.3f%%)", $pairs_with_consensus_edited/$pairs_wrong*100) , $/ if $pairs_wrong;

print "\nTotal mismatches: $total\n";
print "Wrong mismatches (by merger): ", $wrong, sprintf(" (%.3f%%)", $wrong/$total*100), $/ if $total;

print "--------- \n";
print "--------- \n";

## pairs w/ x number of mismatches/pair 
#for (sort {$a <=> $b } keys %mismatches_per_pair) {
#	print $_, "\t", $mismatches_per_pair{$_}, $/;
#}
