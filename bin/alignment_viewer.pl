#!/usr/bin/perl -w
use strict;
use Bio::AlignIO;
use Getopt::Long;
use Data::Dumper;
use CGI qw/:standard start_table end_table start_row end_row/;

my ($infile, $numgap, $outfile);
GetOptions (
	    "infile=s"  => \$infile,    # input alignment (required)
	    "outfile:s" => \$outfile,   # output file (optional -- print to STDOUT otherwise
	    "numgap:i"  => \$numgap);   # number of sequences with terminal gaps allowed (optional) 
                                        # 0-N, where N = num sequences; default = int(N/2 + 0.5)
my $usage = <<END;
./alignment_viewer.pl -i infile [-o outfile, -n numgap]
   n = 0-N, where N = num sequences; default = int(N/2 + 0.5)
END
;

$infile or die $usage;
my $in      = Bio::AlignIO->new( -file => $infile );
my @outfile = (-file => ">$outfile") if $outfile;
my $out     = Bio::AlignIO->new( -format => 'clustalw', @outfile );

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
$slice->match;


my $css = <<END;

table {
 padding:1px;
 border-spacing:0px;
}
td {
  font-family:Courier,monospace;
  color:gray;
}
td.A {
 color:green;
}
td.G {
 color:black;
}
td.T {
 color:red;
}
td.C {
 color:blue;
}
th {
  text-align:left; 
  white-space:nowrap;
  padding-right:3px;
}
div.toggle {
 float:right;
 border:1px solid black; 
 background:ivory;
 cursor:pointer;
}
div.viewport {
 position:absolute;
 top:1px;
 left:1px;
 width:1024px;
 border:2px solid black;
 padding:3px;
 overflow:auto
}

END
;

my $js = <<END;

function toggle(e1,e2) {
  document.getElementById(e1).style.display = 'none';
  document.getElementById(e2).style.display = 'inline';
}
END
;

my $style  = style($css);
my $script = script({type=>'text/javascript'},$js);
print start_html(-title => 'seq_display_mockup',
		 -head  => [$style, $script]);

#$out->write_aln($slice);

my $dec1 = decorate_alignment($slice);
$slice->unmatch;
my $dec2 = decorate_alignment($slice);

my $toggle1 = div({ id => 'seqt', class => 'toggle', onclick => "toggle('dots','seq')"},"Show Sequence");
my $toggle2 = div({ id => 'dots', class => 'toggle', onclick => "toggle('seq','dots')"},"Show Matches");
print div({id => 'dots', class => "viewport" },$toggle1,$dec1);
print div({id => 'seq',  class => "viewport", style => "display:none"},$toggle2,$dec2);
print end_html;

$out->write_aln($aln) if $outfile;


sub decorate_alignment {
  my $aln = shift;

  my @seq = $aln->each_seq;
  my %rseqs;
  for my $seq (@seq) {
    $rseqs{$seq->display_id} = reverse $seq->seq;
  }

  my @labels = map {$_->display_id} @seq;
  
  my @columns;
  for (1..$aln->length) {
    my $col = [];
    push @$col, map {chop $rseqs{$_}} @labels;
    my $top = shift @$col;
    my $match = grep {$top eq $_ || $_ eq '.'} @$col;
    my $fraction = $match ? $match/@$col : 0;
    unshift @$col, $top;
    unshift @$col, int($fraction*255 + 0.5);
    push @columns, $col; 
  }
  
  # get top row (fractions)
  my @top = map {shift @$_} @columns;
  my $retval = '<table>';
  $retval .= "\n<tr>\n";
  $retval .= th({align => 'left', nowrap => 'nowrap'}, 'Sequence Conservation');
  for my $f (@top) {
    my $c = 255 - $f;
    my $rgb_hex = sprintf("#%02lx%02lx%02lx", 255, $c, $c);
    $retval .= td({-style => "background:$rgb_hex;border:1px solid $rgb_hex"},'&nbsp;');
    $retval .= "\n";
  }
  $retval .= "\n</tr>\n";

  for my $label (@labels) {
    $retval .= "<tr>\n";
    $retval .= th($label)."\n";
    my @row = map {shift @$_} @columns;
    for my $col (@row) {
      $retval .= td({class => $col},$col) . "\n";
    }
    $retval .= "</tr>\n";
  }
  $retval .= end_table;
  return $retval;
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



