package DNALC::Pipeline::Barcode::Annotation;

use strict;
use warnings;

{
	my %standardCode = (
		'TCA' => 'S',    # Serine
		'TCC' => 'S',    # Serine
		'TCG' => 'S',    # Serine
		'TCT' => 'S',    # Serine
		'TTC' => 'F',    # Phenylalanine
		'TTT' => 'F',    # Phenylalanine
		'TTA' => 'L',    # Leucine
		'TTG' => 'L',    # Leucine
		'TAC' => 'Y',    # Tyrosine
		'TAT' => 'Y',    # Tyrosine
		'TAA' => '*',    # Stop
		'TAG' => '*',    # Stop
		'TGC' => 'C',    # Cysteine
		'TGT' => 'C',    # Cysteine
		'TGA' => '*',    # Stop
		'TGG' => 'W',    # Tryptophan
		'CTA' => 'L',    # Leucine
		'CTC' => 'L',    # Leucine
		'CTG' => 'L',    # Leucine
		'CTT' => 'L',    # Leucine
		'CCA' => 'P',    # Proline
		'CCC' => 'P',    # Proline
		'CCG' => 'P',    # Proline
		'CCT' => 'P',    # Proline
		'CAC' => 'H',    # Histidine
		'CAT' => 'H',    # Histidine
		'CAA' => 'Q',    # Glutamine
		'CAG' => 'Q',    # Glutamine
		'CGA' => 'R',    # Arginine
		'CGC' => 'R',    # Arginine
		'CGG' => 'R',    # Arginine
		'CGT' => 'R',    # Arginine
		'ATA' => 'I',    # Isoleucine
		'ATC' => 'I',    # Isoleucine
		'ATT' => 'I',    # Isoleucine
		'ATG' => 'M',    # Methionine
		'ACA' => 'T',    # Threonine
		'ACC' => 'T',    # Threonine
		'ACG' => 'T',    # Threonine
		'ACT' => 'T',    # Threonine
		'AAC' => 'N',    # Asparagine
		'AAT' => 'N',    # Asparagine
		'AAA' => 'K',    # Lysine
		'AAG' => 'K',    # Lysine
		'AGC' => 'S',    # Serine
		'AGT' => 'S',    # Serine
		'AGA' => 'R',    # Arginine
		'AGG' => 'R',    # Arginine
		'GTA' => 'V',    # Valine
		'GTC' => 'V',    # Valine
		'GTG' => 'V',    # Valine
		'GTT' => 'V',    # Valine
		'GCA' => 'A',    # Alanine
		'GCC' => 'A',    # Alanine
		'GCG' => 'A',    # Alanine
		'GCT' => 'A',    # Alanine
		'GAC' => 'D',    # Aspartic Acid
		'GAT' => 'D',    # Aspartic Acid
		'GAA' => 'E',    # Glutamic Acid
		'GAG' => 'E',    # Glutamic Acid
		'GGA' => 'G',    # Glycine
		'GGC' => 'G',    # Glycine
		'GGG' => 'G',    # Glycine
		'GGT' => 'G',    # Glycine
	);

	my %invertebrateCode = (
		'AGA' => 'S',	# Ser
		'AGG' => 'S',	# Ser
		'ATA' => 'M',	# Met
		'TGA' => 'W',	# Trp
	);

	my %vertebrateCode = (
		'AGA' => '*',	# Stop
		'AGG' => '*',	# Stop
		'ATA' => 'M',	# Met
		'TGA' => 'W',	# Trp
	);

	 my %echinodermCode = (
        'AGA' => 'S',   # Ser
        'AGG' => 'S',   # Ser
        'AAA' => 'N',   # Asn
        'TGA' => 'W',   # Trp
    );

	sub getTransCode {
		my ($trans_table) = @_;

		my $geneticCode = \%standardCode;
		
 		# Create hash %geneticCode conditionally based on what trans table to use
        if ($trans_table == 2) {
            $geneticCode = mergeHashes(\%standardCode, \%vertebrateCode);
        }
        elsif ($trans_table == 5) {
            $geneticCode = mergeHashes(\%standardCode, \%invertebrateCode);
        }
        elsif ($trans_table == 9) {
            $geneticCode = mergeHashes(\%standardCode, \%echinodermCode);
        }

		return $geneticCode;

	}
	
	sub mergeHashes {
		my ($hash1, $hash2) = @_;

		my %new_hash = %$hash1;
		foreach my $key2 (keys %$hash2){
			$new_hash{$key2} = $hash2->{$key2};
		}
		return \%new_hash;
	}

	sub getGCode {
		my($codon, $orf, $pos, $geneticCode) = @_;
		
		my %geneticCode = %$geneticCode;	
		my $code = '';
		
		if(exists $geneticCode{$codon}) {
			$code = $geneticCode{$codon};
		}
		elsif(length $codon < 3) {
			$code = ' ';
		}
		else {
			$code = "X";
		}

		return $code;
	}


	# translate DNA sequence into amino-acids
	# parameters:
	#	$seq - DNA sequence
	#	$orf - reading frame (1,2 or 3)
	#
	sub translate {
		my ($seq, $orf, $trans_table) = @_;
		
		unless ($orf && $orf =~ /^[1-3]$/) {
			print STDERR "ERR: Invalid orf: ", $orf, "\n";
			return;
		}
		
		my $t = '';
		my @stop_codons = ();
		my @start_codons = ();
		
		my $pos = 0 + $orf - 1;
		my $seq_len = length $seq;

		my $geneticCode = getTransCode($trans_table);
		while ($pos < $seq_len) {
			my $codon = substr($seq, $pos, 3);
			my $aa = getGCode($codon, $orf, $pos, $geneticCode);
			
			push @stop_codons, [$pos+1, $codon] if $aa eq '*';
			push @start_codons, [$pos+1, $codon] if $aa eq 'M';
			
			$t .= $aa;
			
			$pos += 3;
		}
		
		return $t, \@start_codons, \@stop_codons;
	}


	# to be implemented
	sub annotate_fungi {

	}

	# method for getting the rbcL/COI annotation
	# param $seq		The sequence to be annotated
	# param $primer		Currently supported primers: rbcL, coi
	# param $organism	The name of the organism 
	# $trans_table		The Translation Table number to use (ex: 5 - Invertebrate Mitochondrial)
	sub annotate_barcode {
		my ($seq, $primer, $organism, $trans_table, $common_name, $isolation_source) = @_;
		my ($orf, $translation) = (0, '');
		
		my $seq_len = length $seq;
		
		$seq =~ s/[^cgtan]//ig;
	
		# find the 1st reading frame without a stop codon
			for (1 .. 3) {
				my ($ts, $start_codons, $stop_codons) = translate($seq, $_, $trans_table);
				unless (@$stop_codons) {
					$orf = $_;
					$translation = $ts;
					last;
				}
			}
		
		unless ($orf) {
			print STDERR "ERR: can't build annotation?!\n";
			return;
		}
		
		my ($organelle, $product_full, $gene, $protein_id );
		
		if ($primer =~ /rbcl/i) {
			$gene = 'rbcL';
			$organelle = 'plastid:chloroplast';
			$product_full = 'ribulose-1,5-bisphosphate carboxylase/oxygenase large subunit';
		}
		elsif ($primer =~ /co(?:i|1)/i) {
			$gene = 'COI';
			$organelle = 'Mitochondria';
			$product_full = 'cytochrome c oxidase subunit I';
		}
		
		my $annotation = '';
		$annotation .= "1	$seq_len	source\n";
		$annotation .= "				organism	$organism\n";
		$annotation .= "				organelle	$organelle\n";
		$annotation .= "				mol_type	genomic DNA\n";
		$annotation .= "				host	$common_name\n";
		$annotation .= "				isolation_source	$isolation_source\n";
		$annotation .= "<1	>$seq_len	gene\n";
		$annotation .= "				gene	$gene\n";
		$annotation .= "<1	>$seq_len	CDS\n";
		$annotation .= "				gene	$gene\n";
		$annotation .= "				codon_start	$orf\n";
		$annotation .= "				transl_table	$trans_table\n";
		$annotation .= "				product	$product_full\n";
		$annotation .= "				translation	$translation\n";
		
		return $annotation;
	}

}

1;

__END__

package main;


my $seq = "ATATTGGNGTTTTATATTTTATTTTTGNNGNTTNTNCAGGGATAATAGGAACNTTATTTTCAGTTTTCNTTAGAANTGAATTAAGTTGGCCAGGAAATCAAATTTTAGAAGGTAATCATCAATTATATAATGTTCTTGTTACTGCTCATGCTATTGTTATGATTTTTTTTATGGTTATGCCAGCAATGATCGGAGATTTGGTAATGTGTTTGTACCTTTAATGATTGGTGCACCAGATATGGCTTTTCCAAGATTAAATAATATTAGTTTTTGGTTATTGCCACCTTCTTTCATTTTATTATTACTTTCTGCTTTTGTAGAAGGTGGGGCTGGAACTGGTTGGACTATTTATCCACCATTATCTAGTATAGAAAATCATTCCGGAGGCGCGGTTGATTTAGCTATTTTTAGTTTACATTTATCAGGTGCTTCTTCATTATTAGGTGCTATTAATTTTATTACAACAATTATTAATATGAGAACACCTCAAATGACTTGGAATAGATTACCTTTATTTGTTTGGGCTATTTTTATTACAGCTTTTTTATTATTGCTTTCATTACCAGTTTTAGCTGGTGGGATTACTATGTTATTAACAGATCGTAATTTTAATACTACTTTTTTTGATCCATTGGGAGGTGGAGATCCTATCTTATTTCAACATCTTTTTTGATTTTTTGGTCACCCTGAAGTTTAGTCNTACGGGTTTTCCTGAA";

print DNALC::Pipeline::Barcode::Annotation::annotate_barcode($seq, 'rbcL');

