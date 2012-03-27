#!/usr/bin/perl -w

use strict;

use Bio::AlignIO;
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

my $aln = $in->next_aln;;
my @seq = $aln->each_seq;

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

my $style = ($is_amino ? '<link rel="stylesheet" href="/css/alignment_viewer_amino.css" />' : '<link rel="stylesheet" href="/css/alignment_viewer.css" />');
#my $style = '<link rel="stylesheet" href="/css/alignment_viewer_amino.css" />';
my $script = '<script type="text/javascript" src="/js/prototype-1.6.1.js"></script>' . "\n";
$script .= '<script type="text/javascript" src="/js/alignment_viewer.js"></script>';
my $buttons = '<div><input type="image" class="controls" id="barcode_but" onclick="barcodeView()" src="/images/barcode_but.png"/> <input type="image" class="controls" id="zoom_out" onclick="zoomOut()" src="/images/zoom_out_but.png" /><input type="image" class="controls" id="zoom_in" onclick="zoomIn()" src="/images/zoom_in_but.png"/> <input type="image" class="controls" id="sequence_but" onclick="seqView()" src="/images/sequence_but.png" /></div>';
my $body_tag = '<body onload="resizeFrame(parent.window.document.getElementById(\'aframe\'))">';

my $dec = decorate_alignment($slice);
my $retval = $dec->{retval};
my $barcode = $dec->{barcode};
my $labels = $dec->{labels};

if ($html_out->open($htmlout, "w")){
	print $html_out '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">', "\n";
	print $html_out '<html xmlns="http://www.w3.org/1999/xhtml">';
	print $html_out '<head>';
	print $html_out '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />';
	print $html_out '<title>Alignment Viewer</title>';
	print $html_out $style, "\n", $script, "\n", "</head>", "\n", $body_tag, "\n";
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
	print $html_out '</body>', "\n", '</html>';

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
	## abundance
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
	#my $cc = 0;
	#for (@columns){
	#	print @$_, " $fractions[$cc]", $/;
	#	$cc++;
	#}

	## if it's an amino acid sequence, make a histogram here, otherwise
	## make the stacked column style sequence conservation row.
	if ($is_amino){
		$retval .= '<div class="row">';
		for my $h (@histogram_data){
			my $height = ($h*100);
			$retval .= "<div class='bar'><div class='hgram' style='height:$height%'>&nbsp;</div></div>";
		}
		$retval .= '</div><!--end row-->';
	}
	else{
		## Making the 'stacked column' style sequence conservation here
		## store it in retval bc this is only shown in sequence view
		$retval .= '<div class="row">';
		for my $mms (@positions){
			my $num_mm = @$mms;

			$retval .= '<div class="bar">';	
			if ($num_mm == 0){
				$retval .= "<div class='hbar cons_cons'>&nbsp;</div>";
			}
			elsif ($num_mm == 1){
				$retval .= "<div class='hbar cons_" . @$mms[0] ." cons_hundred'>&nbsp;</div>";
			}
			elsif ($num_mm == 2){
				$retval .= "<div class='hbar cons_" . @$mms[0] . " cons_hundred'>&nbsp;</div>";
				$retval .= "<div class='hbar cons_" . @$mms[1] . " cons_fifty'>&nbsp;</div>";
			}
			elsif ($num_mm == 3){
				$retval .= "<div class='hbar cons_" . @$mms[0] . " cons_hundred'>&nbsp;</div>";
				$retval .= "<div class='hbar cons_" . @$mms[1] . " cons_sixtysix'>&nbsp;</div>";
				$retval .= "<div class='hbar cons_" . @$mms[2] . " cons_thirtythree'>&nbsp;</div>";
			}
			else{
				$retval .= "<div class='hbar cons_err'>&nbsp;</div>";
			}
			$retval .= '</div>'; #end div bar#
		}
		$retval .= '</div><!--end row-->';
	}

	## Making the histogram here 
	## store it in barcode because the histogram
	## will be displayed in barcode mode
	$barcode .= '<div class="row">';
	for my $h (@histogram_data){
	   my $height = ($h*100);
	   $barcode .= "<div class='bar'><div class='hgram' style='height:$height%'>&nbsp;</div></div>";
	}
	$barcode .= '</div><!--end row-->';

	## Getting the labels and creating the barcode and sequence views here 
	## first - add a label for the sequence conservation row
	$labels .= "<div class='labels row'>Sequence Conservation</div>\n";
	for my $l (@labels) {
		$labels .= "<div class='labels row'>$l</div>\n";

		$retval .= '<div class="row">';
		$barcode .= '<div class="row">';
		my @row = map {shift @$_} @columns;
		my $x = 0;
		for my $col (@row) {	
			my $n;	
			my $class;
			$n = ($col eq '.' ? "&nbsp;" : $col); 
			#$class = ($col ne '.' && $col ne 'A' && $col ne 'T' && $col ne 'C' && $col ne 'G' ? 'x' : $col); 
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
