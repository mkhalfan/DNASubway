#!/usr/bin/perl

use strict;

use DNALC::Pipeline::Phylogenetics::DataFile;
use DNALC::Pipeline::Phylogenetics::DataSequence;
use DNALC::Pipeline::Phylogenetics::PairSequence;
use DNALC::Pipeline::Phylogenetics::Pair;
use Data::Dumper;

my $wrong = 0;
my $total = 0;

my $pairs = DNALC::Pipeline::Phylogenetics::Pair->retrieve_all;

while (my $pair = $pairs->next) {
	my $muscle_alignment = $pair->alignment;
	#my $consensus = $pair->consensus;
	next if $muscle_alignment eq "";

	my @alignment_line_1 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[0]));
	my @alignment_line_2 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[1]));
	my @alignment_line_3 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[2]));
	my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]); #Sequence 1
	my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]); #Sequence 2
	my ($display_name_3, $consensus) = ($alignment_line_3[0], $alignment_line_3[1]); #Consensus

	next if length($seq1 ) != length($consensus);

	my @pair_seq = $pair->paired_sequences;
	#print STDERR Dumper( \@pair_seq), $/;
	next unless @pair_seq;

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
	my @qs1 = $df1->quality_values();
	if ($df_1_strand eq "R"){
		@qs1 = reverse @qs1;
	}
	my $df2 = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($df_id_2);
	next unless $df2 && $df2->file_type eq "trace";
	my @qs2 = $df2->quality_values();
	if ($df_2_strand eq "R"){
		@qs2 = reverse @qs2;
	}
	next unless(@qs2 && @qs1);
	print "$pair: ", length $seq1, "\t", scalar @qs1, $/;
	print "$pair: ", length $seq1, "\t", scalar @qs2, $/;

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

	for (my $i = 0; $i <= length($seq1); $i++){
		my $a = substr($seq1, $i, 1);
		my $b = substr($seq2, $i, 1);
		my $c = substr($consensus, $i, 1);

		if ($a ne "N" && $b ne "N"){
			next if ($a eq '-' || $b eq '-');
				if ($a ne $b){ # there is a mismatch
					$total++;
					if ($qs1[$i] > $qs2[$i]){
						if ( $a ne $c ){
							$wrong++;
							#print "Pos: $i \nA: $a \nB: $b \nC: $c \n  ";
							#print substr($consensus, $i-2, 5), $/;
						}
					}
					else { # $qs1[i] < $qs2[i]
						if ($b ne $c){
							$wrong++;	
							#print "Pos: $i \nA: $a \nB: $b \nC: $c \n  ";
						}
					}
				}
		}
	}

}

#print "\nC: ", join( " ", map {sprintf("%3s", $_)} split(//, $consensus)), $/;
print "Wrong: $wrong \n";
print "--------- \n";
print "Total: $total \n\n";
print "=", $wrong/$total, $/;
