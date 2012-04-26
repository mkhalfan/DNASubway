#!/usr/bin/perl -w

use strict;

use Bio::AlignIO;
use Bio::LocatableSeq;
use Bio::SimpleAlign;
use Getopt::Long;
use Data::Dumper;
use IO::File ();
#use CGI qw/:standard start_table end_table start_row end_row/;

my ($infile, $htmlout, $numgap, $outfile);
my $is_amino = '';
GetOptions	(
	    "infile|i=s"  => \$infile,    # input alignment (required)
		"htmlout|h=s" => \$htmlout,	  # html output file (required)
	    "outfile|o:s" => \$outfile,   # output file (optional -- print to STDOUT otherwise)
		"is_amino"	  => \$is_amino,  # flag to indicate protein sequences
	    "numgap|n:i"  => \$numgap,    # number of sequences with terminal gaps allowed (optional) 
                                      # 0-N, where N = num sequences; default = int(N/2 + 0.5)
);

my $usage = <<END;
./alignment_viewer.pl -i infile -h htmloutfile [-o outfile, -n numgap --is_amino]
   n = 0-N, where N = num sequences; default = int(N/2 + 0.5)
   --is_amino is the switch to include if it's protein sequences
END
;

($infile && $htmlout) or die $usage;
my $in = Bio::AlignIO->new( -file => $infile );
my @outfile = (-file => ">$outfile") if $outfile;
my $out = Bio::AlignIO->new( -format => 'fasta', @outfile );
my $html_out = IO::File->new;

my %seqs;
my %rseqs;

my $aln = $in->next_aln;

my $consensus = $aln->consensus_string();
my $consensus_seq = new Bio::LocatableSeq ( 
		-seq => $consensus,
		-id => 'Consensus',
		-start => 1,
		-end => length($consensus),
);
$aln->add_seq($consensus_seq, 0);

my @seq = $aln->each_seq;

my $pairwise_data = calculate_pairwise_ids($aln);
#print Dumper (\%pairwise_ids), $/;
my $pairwise_div = create_pairwise_table($pairwise_data);

for my $seq (@seq) {
	$seqs{$seq->display_id} = $seq->seq;
	$rseqs{$seq->display_id} = reverse $seq->seq;
}

# preserve seq ID order
@seq = map {$_->display_id} @seq;
$numgap = int(@seq/2+0.5) unless defined $numgap;
my $slice = auto_flush(\%seqs,\%rseqs,$aln);
$out->write_aln($slice) if $outfile; #this creates the new *trimmed* alignment output file
$slice->match;

my $seq_but_prefix = ($is_amino ? 'aa' : 'nuc');
my $buttons = '<div><input type="image" class="controls" id="barcode_but" onclick="barcodeView()" src="/images/barcode_but.png"/> <input type="image" class="controls" id="zoom_out" onclick="zoomOut()" src="/images/zoom_out_but.png" /><input type="image" class="controls" id="zoom_in" onclick="zoomIn()" src="/images/zoom_in_but.png"/> <input type="image" class="controls" id="sequence_but" onclick="seqView()" src="/images/' . $seq_but_prefix . '_sequence_but.png" />';
$buttons .= ($is_amino ? '<div id="legend_but" onclick="$(\'legend\').toggle();">COLOR CODES</div>' : '');
$buttons .= '<div id="pairwise_but" onclick="$(\'pairwise_div\').toggle();">SEQUENCE SIMILARITY</div>';
$buttons .= "</div>";

my $css = ($is_amino ? 'alignment_viewer_amino.css' : 'alignment_viewer_nucleotide.css');

my $set_css = <<END
<script type="text/javascript">
  var fileref = document.createElement("link");
  fileref.setAttribute("rel", "stylesheet");
  fileref.setAttribute("type", "text/css");
  fileref.setAttribute("href", '/css/$css');
  document.getElementsByTagName("head")[0].appendChild(fileref);
</script>
END
;

my $dec = decorate_alignment($slice);
my $retval = $dec->{retval};
my $barcode = $dec->{barcode};
my $labels = $dec->{labels};
my $div_height = (keys %{$aln->{_order}}) * 22 + 140;

if ($html_out->open($htmlout, "w")){
	print $html_out $set_css, "\n";
	print $html_out $pairwise_div, "\n";
	print $html_out '<div id="muscle_post_processor_output" style="height:' . $div_height . 'px;">', "\n";
	print $html_out $buttons, "\n";
	print $html_out '<div id="viewport" class="viewport">', "\n";
	print $html_out '<div id="labels">', "\n", $labels, '</div>', "\n";
	print $html_out '<div id="alignment">', "\n";
	print $html_out '<div id="sequence" class="fingerprint" style="display:none">', "\n";
	print $html_out $retval, "\n";
	print $html_out '</div><!--end sequence div-->', "\n";
	print $html_out '<div id="barcode">', "\n";
	print $html_out $barcode, "\n";
	print $html_out '</div><!--end barcode div-->', "\n";
	print $html_out '</div><!--end alignment div-->', "\n";
	print $html_out '</div><!--end viewport div-->', "\n";
	print $html_out '<input type="hidden" id="div_width" value="1" />', "\n";
	print $html_out '</div><!--end muscle_post_processor_output-->';

	undef $html_out
}
else{
	print STDERR "Could not open html out file to write \n";
}

sub decorate_alignment {
	my $aln = shift;

	my @seq = $aln->each_seq;
	my %rseqs;
	for my $seq (@seq) {
		$rseqs{$seq->display_id} = reverse $seq->seq;
	}
	my @labels = map {$_->display_id} @seq;

	## The @positions array will contain $mismatch arrayrefs which will 
	## hold the variations which exist at that position in the alignment. 
	## The element number in the @positions array corresponds to the 
	## position in the alignment. The $mismatch arrayref holds the variants
	## themselves and only stores which variants are present, NOT their 
	## abundance - for use in the sequence variation row
	my @positions;

	## The @histogram_data array will hold the fraction of conservation
	## at each position in the alignment. Position in the array
	## corresponds to position in the alignment. We only look at
	## standard bases (ACTG) when calculating conservation (ie. an 'N' 
	## or '-' or other ambiguous char would not count as an unconserved 
	## base, we don't want to indicate these in the histogram as unconserved
	## regions). The @histogram_data array is used to produce the histogram.
	my @histogram_data; 

	## The @fractions array will hold the fraction of conservation in
	## each position in the alignment. The difference between @fractions
	## and @histogram_data is that in the @fractions array, we ARE 
	## considering ambigous bases as being unconserved regions (this is
	## in contrast to @histogram_data which ignores ambiguous bases).
	## This array will be used to determine whether a particular base 
	## position should be displayed in the 'barcode'(since we only want
	## to display variant positions, we do not want to display conserved
	## regions).
	my @fractions;

	my @columns;
	for (1..$aln->length) {
		my $col = [];
		push @$col, map {chop $rseqs{$_}} @labels;
	
		## Create/populate the mismatch arrayref. This arrayref holds 
		## the variants themselves and only stores which variants are 
		## present, NOT their abundance (ex: will not store an 'A'
		## if an 'A' has already been stored). We do this because 
		## to create the 'stacked column' style sequence conservation,
		## we only want to know what variants are present, not their
		## quantities.
		## NEW: We only do this step if the sequence is not an amino
		## acid sequence. If it is an amino acid sequence, we just
		## use the histogram (calculated in the next step).
		my $mismatches = [];
		if (!$is_amino){
			for my $x (@$col){
				if (($x ne @$col[0]) && ($x eq 'A' || $x eq 'T' || $x eq 'C' || $x eq 'G') && (!("@$mismatches" =~ /$x/))){
					push @$mismatches, $x;
				}
			}
			push @positions, $mismatches;
		}
		
		my $top = shift @$col;
		
		## $match is used to calculate $conservation which is pushed to
		## the @histogram_data array, which is then used to generate
		## the histogram. Note: For this case, we are NOT looking at
		## ambiguous bases (ie. they do not count as a mismatch with 
		## regards to the histogram).
		my $match;
		if ($is_amino){
			$match = grep {$top eq $_ || $_ !~ /[ARNDCEQGHILKMFPSTWYV]/} @$col;
		}
		else {
			$match = grep {$top eq $_ || $_ !~ /[ACTG]/} @$col;
		}
		my $conservation = $match ? $match/@$col : 0;
		push @histogram_data, $conservation;

		## $match2 is used to calculate $fraction which is pushed to
		## the @fractions array. Note: For this case, we are looking
		## at all possible mismatches including ambiguous bases. We
		## use this variable to determine what columns to show in
		## our display as having mismatches (any).
		my $match2 = grep {$top eq $_ || $_ eq '.'} @$col;
		my $fraction = $match2 ? $match2/@$col : 0;
		push @fractions, $fraction;

		unshift @$col, $top;
		#unshift @$col, int($fraction*255 + 0.5);
		push @columns, $col;
	}
	
	## $both will hold things which will be pushed to both $retval and $barcode
	## row_1 holds the histogram and sequence positions/numering
	my $both = '<div class="row_1"><div class="row" style="bottom:0;position:absolute">';
	my $x = 1;
	for my $h (@histogram_data){
		my $height = ($h*100);
		my $title = sprintf("%.1f", $height);
		$both .= "<div class='bar' data-title='$title%'>";
		$both .= ($x == 1 || $x % 100 == 0 ? "<div style='position:absolute;color:black;top:-21px;background-color:white'>$x</div>" : '');
		$both .= "<div class='hgram' style='height:$height%'>&nbsp;</div></div>";
		$x++;
	}
	$both .= '</div><!--end row-->';
	$both .= '</div><!--end row_1-->';

	## if it's not a protein sequence, add the sequence variation row here
	if (!$is_amino){
		## Making the 'stacked column' style sequence conservation here
		$both .= '<div class="row">';

		for my $mms (@positions){
			my $num_mm = @$mms;

			$both .= "<div class='bar'>";

			if ($num_mm == 0){
				$both .= "<div class='hbar cons_cons'>&nbsp;</div>";
			}
			elsif ($num_mm == 1){
				$both .= "<div class='hbar cons_" . @$mms[0] ." cons_hundred'>&nbsp;</div>";
			}
			elsif ($num_mm == 2){
				$both .= "<div class='hbar cons_" . @$mms[0] . " cons_hundred'>&nbsp;</div>";
				$both .= "<div class='hbar cons_" . @$mms[1] . " cons_fifty'>&nbsp;</div>";
			}
			elsif ($num_mm == 3){
				$both .= "<div class='hbar cons_" . @$mms[0] . " cons_hundred'>&nbsp;</div>";
				$both .= "<div class='hbar cons_" . @$mms[1] . " cons_sixtysix'>&nbsp;</div>";
				$both .= "<div class='hbar cons_" . @$mms[2] . " cons_thirtythree'>&nbsp;</div>";
			}
			else{
				$both .= "<div class='hbar cons_err'>&nbsp;</div>";
			}
			$both .= '</div>'; #end div bar#
		}
		$both .= '</div><!--end row-->';
	}

	$retval .= $both;
	$barcode .= $both;

	## Getting the labels and creating the barcode and sequence views here 
	## first - add a label for the seq conservation row and a blank one to compensate for the numbers above the conservation (hgram) row
	$labels .= "<div class='labels row'>&nbsp</div>"; #this blank row needed to compensate for the numbers above the Conservation row
	$labels .= "<div class='labels row'>Sequence Conservation</div>\n";
	## if it's not a protein sequence, add a label for the sequence variation row
	$labels .= (!$is_amino ? "<div class='labels row'>Sequence Variation</div>" : ''); 
	
	## $z is counter which adds the sequence number to each sequence. ex: 1. Sequence A
	my $z = 0;
	for my $l (@labels) {
		## when z = 0, this is the first row, the consensus sequence. Don't number the consensus
		my $seq_num = ($z > 0 ? "$z." : '');
		$labels .= "<div class='labels row'>$seq_num $l</div>\n";
		$z++;

		$retval .= '<div class="row">';
		$barcode .= '<div class="row">';
		my @row = map {shift @$_} @columns;
		my $x = 0;
		for my $col (@row) {	
			my $n;	
			my $class;
			$n = ($col eq '.' ? "&nbsp;" : $col); 
			$class = ($col eq '-' ? 'dash' : $col);
			$retval .= "<div class='$class'>$n</div>";
			if ($fractions[$x] != 1){
				$barcode .= "<div class='$class'>&nbsp;</div>";
			}
			else {
				
				$barcode .= "<div class='grey'>&nbsp;</div>";
			}
			$x++;

		}
		$retval .= "</div><!--end row-->\n";
		$barcode .= "</div><!--end row-->\n";
	}
	return {retval => $retval, barcode => $barcode, labels => $labels};
}

sub auto_flush {
	my $seq = shift;
	my $rev = shift;
	my $aln = shift;
	$seq && $rev && $aln || die "I was expecting three arguments for the auto_flush function\n";
  
	my @seq = values %$seq;
	my $min_nogap = @seq - $numgap - 1;

	my $nogap = 0;
	my $right_end = $aln->length;

	while (@seq && $nogap <= $min_nogap) {
		$right_end--;
		$nogap = 0;
		for (@seq) {
			$nogap++ unless chop eq '-';
		}
	}

	@seq = values %$rev;
	my $left_end = 0;
	$nogap = 0;

	while (@seq && $nogap <= $min_nogap) {
		$left_end++;
		$nogap = 0;
		for (@seq) {
			$nogap++ unless chop eq '-';
		}
	}

	return $aln->slice($left_end,$right_end);
}

sub calculate_pairwise_ids {
	my ($aln) = @_;
	my %pairwise_ids = ();
	my $num_seqs = $aln->no_sequences();
	my @seq = $aln->each_seq;

	my $x = 1;
	for my $a (@seq) {
		my $y = 1;
		for my $b (@seq) {
			my $key = $x . '-' . $y;
			if ($a->display_id eq $b->display_id){
				$pairwise_ids{$key} = '-';
				$y++;
				next;
			}

			my $pairwise_aln = new Bio::SimpleAlign();
			$pairwise_aln->add_seq($a);
			$pairwise_aln->add_seq($b);
			
			my $percent_id = $pairwise_aln->percentage_identity;
			$pairwise_ids{$key} = sprintf("%.2f", $percent_id);

			$y++;
		}
		$x++;
	}

	return {pairwise_ids => \%pairwise_ids, num_seqs => $num_seqs};
}

sub create_pairwise_table {
	my ($pairwise_data) = @_;
	my $num_seqs = $pairwise_data->{num_seqs};
	my %pairwise_ids = %{$pairwise_data->{pairwise_ids}};

	my $div;
	$div  = '<div id="pairwise_div" style="display:none">' . "\n";
	$div .= '<table id="pairwise_table" cellspacing=0>' .  "\n";
	$div .= '<tr>'. "\n";
	$div .= '<td></td>' . "\n";
	for (my $y = 1; $y <= $num_seqs; $y++){
		my $seq_value = ($y == 1 ? 'C' : $y - 1);
		$div .= "<td>$seq_value</td>\n";
	}
	$div .= '</tr>' . "\n";

	for (my $x = 1; $x <= $num_seqs; $x++){
		$div .= '<tr>';
		my $seq_value = ($x == 1 ? 'C' : $x - 1);
		$div .= "<td>$seq_value</td>\n";
		for (my $y = 1; $y <= $num_seqs; $y++){
			#print "$x-$y = ", $pairwise_ids{$x . '-' . $y}, $/;
			my $key = $x . '-' . $y;
			my $value = $pairwise_ids{$key};
			$div .= ($value eq '-' ? "<td>$value</td>\n" : "<td>$value%</td>\n");
		}
		$div .= '</tr>';
	}
	$div .= '</table>' . "\n";
	$div .= '</div>' ."\n";
	return $div;
}
