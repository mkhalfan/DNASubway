[DETAIL SELECT MENU]
width = 250
html  = <table style="width:100%">
         <tr>
           <th style="background:lightgrey;cell-padding:5">
             SELECTION
             <span style="right:0px;position:absolute;color:blue;cursor:pointer"
                   onclick="SelectArea.prototype.cancelRubber()">
               [X]
             </span>
           </th>
         </tr>
         <tr>
           <td>
             <span style="color:blue;cursor:pointer" onclick="SelectArea.prototype.clearAndSubmit()">
              Zoom in
             </span>
           </td>
         </tr>
         <tr>
           <td>
             <span style="color:blue;cursor:pointer" onclick="SelectArea.prototype.clearAndRecenter()">
               Recenter on this region
             </span>
           </td>
         </tr>
         <tr>
           <td onmouseup="SelectArea.prototype.cancelRubber()">
             <a href="/cgi-bin/apollo_request_region.pl?selection=SELECTION">
              Open this section in Apollo
             </a>
           </td>
         </tr>
       </table>



[Augustus_Genes]
feature      = gene:AUGUSTUS
glyph        = gene
base         = 1
sub_part     = exon
#ignore_sub_part = polypeptide 
fgcolor      = green
bgcolor      = lightgreen
height       = 8
key          = Augustus Genes
balloon hover = <b>$name</b> is a predicted gene spanning $ref from $start to $end. Click for more details.

[FgenesH]
feature      = gene:FGenesH_Monocots gene:FGenesH gene:FGenesH_Dicots
glyph        = gene
sub_part     = exon
bgcolor      = green
#ignore_sub_part = polypeptide
label_transcripts = 1
thin_utr     = 1
pad_bottom   = 3
key          = FGenesH

[CDS]
feature      = mRNA
sub_part     = CDS
glyph        = cds
height       = 20
key          = CDS

[Snap]
feature      = gene:SNAP
sub_part     = exon
ignore_sub_part = polypeptide
glyph        = gene
bgcolor      = green
label_transcripts = 1
thin_utr     = 1
pad_bottom   = 3
key          = Snap

[tRNA]
feature      = gene:tRNAScan-SE
fgcolor      = black
stranded     = 1
key          = Predicted tRNAs

[Repeats]
feature      = repeat_region
glyph        = generic
bgcolor      = black
fgcolor      = black
key          = Repeats

[Translation]
glyph        = translation
global feature = 1
height       = 40
fgcolor      = purple
strand       = +1
translation  = 6frame
key          = 6-frame translation

[DNA/GC Content]
glyph        = dna
global feature = 1
height       = 40
do_gc        = 1
strand       = both
fgcolor      = red
axis_color   = blue

[Blastn]
feature      = match:BLASTN
glyph        = segments
fgcolor      = red
stranded     = 1
height       = 8
description = sub {
        my $f = shift;
        my ($desc) = $f->attributes('description');
        return $desc;
  }
key          = Blastn

[Blastx]
feature      = match:BLASTX
glyph        = segments
fgcolor      = magenta
key          = Blastx



#[BLAST]
#feature      = match
#glyph        = segments
#description = sub {
#        my $f = shift;
#        my ($desc) = $f->attributes('description');
#        return $desc;
#  }
#key          = blast results

[usergenes]
feature     = gene:user
glyph       = gene
bgcolor     = red
key         = User created genes
