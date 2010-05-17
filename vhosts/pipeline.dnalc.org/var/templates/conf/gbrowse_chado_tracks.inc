[DETAIL SELECT MENU]
width = 250
html  = <div style="width:100%">
         <ul style="list-style: none; padding: 2px;">
           <li style="background:lightgrey;">
             SELECTION
             <span style="right:0px;position:absolute;color:blue;cursor:pointer"
                   onclick="SelectArea.prototype.cancelRubber()"> [X] </span>
           </li>
           <li>
             <span style="color:blue;cursor:pointer" onclick="SelectArea.prototype.clearAndSubmit()">Zoom in</span>
           </li>
           <li>
             <span style="color:blue;cursor:pointer" onclick="SelectArea.prototype.clearAndRecenter()">Recenter on this region</span>
           </li>
           <li onmouseup="SelectArea.prototype.cancelRubber()">
             <span style="color:blue;cursor:pointer" onclick="parent.createTargetPoject('SELECTION');//parent.close_windows()">
				Send NAME to TARGeT
			</span>
           </li>
       </ul>
	   </div>



[Augustus]
feature      = gene:AUGUSTUS
glyph        = gene
base         = 1
#sub_part     = exon
#ignore_sub_part = polypeptide 
fgcolor      = #0f6969
bgcolor      = #0f6969
height       = 8
das category = transcription
key          = Augustus Predicted Genes
balloon hover = <b>$name</b> is a predicted gene spanning $ref from $start to $end. Click for more details.

[FGenesH]
feature      = gene:FGenesH_Monocots gene:FGenesH gene:FGenesH_Dicots
glyph        = gene
sub_part     = exon
fgcolor      = #589c7f
bgcolor      = #589c7f
#ignore_sub_part = polypeptide
label_transcripts = 1
thin_utr     = 1
pad_bottom   = 3
das category = transcription
balloon click width = 500
balloon click = url:/project/gene_options?ref=$ref;name=$name;start=$start;end=$end;id=$id
key          = FGenesH Predicted Genes

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
fgcolor      = #a5cba9
bgcolor      = #a5cba9
label_transcripts = 1
thin_utr     = 1
pad_bottom   = 3
das category = transcription
key          = Snap Predicted Genes

[tRNA]
feature      = gene:tRNAScan-SE
fgcolor      = #ac307f
bgcolor      = #ac307f
stranded     = 1
das category = transcription
key          = Predicted tRNAs

[Repeats]
feature      = repeat_region
glyph        = generic
bgcolor      = #663187
fgcolor      = #663187
das category = repeat
key          = Repeats

[Translation]
glyph        = translation
global feature = 1
height       = 40
fgcolor      = purple
strand       = +1
translation  = 6frame
das category = translation
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
#fgcolor      = #b21a1f
#bgcolor      = #b21a1f
fgcolor      = rgb(196,143,14)
bgcolor      = rgb(196,143,14)
stranded     = 1
height       = 8
description = sub {
        my $f = shift;
        my ($desc) = $f->attributes('description');
        return $desc;
  }
das category = transcription
key          = BlastN

[Blastx]
feature      = match:BLASTX
glyph        = segments
fgcolor      = #925732
bgcolor      = #925732
das category = transcription
key          = BlastX

[Blastn_user]
feature      = match:BLASTN_USER
glyph        = segments
fgcolor      = rgb(196,143,14)
bgcolor      = rgb(196,143,14)
stranded     = 1
height       = 8
description = sub {
        my $f = shift;
        my ($desc) = $f->attributes('description');
        return $desc;
  }
#das category = transcription
key          = User BlastN

[usergenes]
feature     = gene:user
glyph       = gene
bgcolor     = rgb(51,102,255)
das category = transcription
key         = User Annotation
