#!/usr/bin/perl -w
use strict;


use File::Slurp qw/read_file/;
use DNALC::Pipeline::App::Phylogenetics::ProjectManager ();
use DNALC::Pipeline::Phylogenetics::DataSequence ();
use DNALC::Pipeline::Phylogenetics::Pair;
use DNALC::Pipeline::Phylogenetics::DataFile;
use DNALC::Pipeline::Config ();
use JSON::XS ();
use Data::Dumper;


sub trim($){
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

my $pid = 399;
my $pair_id = 683;
#my $pos = 688;
my $pos = 70;

	my $json = JSON::XS->new->ascii;
	my $pair = DNALC::Pipeline::Phylogenetics::Pair->retrieve($pair_id);
	my @pseq = sort {$a->seq->display_id cmp $b->seq->display_id } $pair->paired_sequences;
	my $data = [];
	my $original_seq_pos;
	my $seq_substring;
	my $dash_count;
	my $reversed_seq;
	my $trimmed;
	my $reverse_flag = 0;
	my $offset = 0;
	
	
	# ------------------------------
	# Parse the Alignment Data
	# ------------------------------
	my $alignment = $pair->alignment;
	my @aln_lines = sort ((split('\n', $alignment))[0, 1]);

# 	my @alignment_line_1 = (split(': ', (split('\n', $alignment))[0]));
# 	my @alignment_line_2 = (split(': ', (split('\n', $alignment))[1]));
# 	my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]);
# 	my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]);


	for (0, 1) {
		my ($display_name, $seq) = split('\s*:\s*', $aln_lines[$_]);

		my $file = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($pseq[$_]->seq->file_id);
		
		if ($file->file_type ne 'trace') {
			push @$data, 0;
			next;
		}
	
		my @all_base_locations = $file->base_locations;
		my @all_qscores = $file->quality_values;
		my $all_traces = $file->trace;
		my $entire_sequence =  $file->seq;
		print $_, "{", $display_name, "} ~~ ", length $seq, ' > ', length $entire_sequence,  $/;
		
		# ---------------------------
		# Calculate Position In Original Sequence
		# ---------------------------
		$trimmed = 0;
		if ($pseq[$_]->seq->display_id eq trim($display_name)) {
			$offset = 0;
			if ($pseq[$_]->strand eq "F") {
				$seq_substring = substr $seq, 0, $pos;
				$dash_count = ($seq_substring =~ s/-//g);
				
				if (my $temp = DNALC::Pipeline::Phylogenetics::DataSequenceTrim->retrieve($pseq[$_]->seq->id)){
					$trimmed = $temp->start_pos;
				}
				
				$original_seq_pos = $pos- $dash_count + $trimmed;
				$offset = 3 - ($original_seq_pos - $trimmed)  if $original_seq_pos - $trimmed < 3;
			}
			elsif ($pseq[$_]->strand eq "R") {
				$reverse_flag = 1;

				if (my $temp = DNALC::Pipeline::Phylogenetics::DataSequenceTrim->retrieve($pseq[$_]->seq->id)) {
					print STDERR Dumper( $temp), $/;
					$trimmed = length ($temp->left_trim);
				}

				$reversed_seq = reverse $seq;
				$seq_substring = substr ($reversed_seq, 0, $pos);
				#$seq_substring = substr ($reversed_seq, length($seq) - $pos, $pos);
			print STDERR  'X: ',  0, ' => ',  length($seq) - $pos, $/;
				$dash_count = ($seq_substring =~ s/-//g);
				$original_seq_pos = length($seq) - ($pos + $dash_count) - 1 + $trimmed;
				my ($low, $high) = ($original_seq_pos - 3, $original_seq_pos + 3);
				print STDERR  'x: ', $seq_substring, $/;
				print STDERR  'x: ', $original_seq_pos, $/;
				print STDERR  'x: ', $low, ' -> ', $high, $/;

	if (1) {
				#$seq_substring = substr ($seq, 0, $pos);
			print STDERR  'Y: ', length($seq) - $pos, ' => ',  length($seq), $/;
				$seq_substring = substr ($seq, length($seq) - $pos, length($seq));
				$dash_count = ($seq_substring =~ s/-//g);
				$original_seq_pos = length($entire_sequence) - ($pos + $dash_count) - 1 + $trimmed;
				my ($low, $high) = ($original_seq_pos - 3, $original_seq_pos + 3);
				print STDERR  'y: ', $seq_substring, $/;
				print STDERR  'y: ', $original_seq_pos, $/;
				print STDERR  'y: ', $low, ' -> ', $high, $/;
	}
			}
		}
	} __END__
		# ---------------------------

		my ($low, $high) = ($original_seq_pos - 3, $original_seq_pos + 3);
		$low = $trimmed if $low < $trimmed;
		#$high = ($#all_base_locations - $trimmed) if $high > ($#all_base_locations - $trimmed);

		my $qscores = [@all_qscores[$low .. $high]];
		my $sequence = substr $entire_sequence, $low, $high - $low + 1;
		my $five_bases_down_pos = $all_base_locations[$low];
		my $five_bases_up_pos = $all_base_locations[$high];
		my $base_locations = [@all_base_locations[$low .. $high]];
		
		my %trace_values = ();
		foreach (keys %$all_traces){
			$trace_values{$_} = [@{$all_traces->{$_}}[$five_bases_down_pos .. $five_bases_up_pos + 5]];
		}
		
		my $d = {
			debug => length($entire_sequence) . '/' . scalar @all_base_locations . '/' . $trimmed,
			seq_id => $pseq[$_]->seq->id,
			seq_display_id => $pseq[$_]->seq->display_id,
			sequence => $sequence,
			#len => length $entire_sequence,
			qscores => $qscores,
			#trace_values => \%trace_values,
			base_locations => "@$base_locations",
			position => $original_seq_pos,
			reverse_flag => $reverse_flag,
			offset => $offset,
			high => $high,
			low => $low,
			#pos => { $pos => $all_base_locations[$pos], down => $five_bases_down_pos, up => $five_bases_up_pos},
		};
		
		push @$data, $d;
}

print STDERR Dumper( $data ), $/;
