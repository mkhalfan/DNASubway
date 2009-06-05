[Augustus_Genes]
feature      = gene:AUGUSTUS
glyph        = gene
base         = 1
#ignore_sub_part = polypeptide 
fgcolor      = green
bgcolor      = lightgreen
height       = 8
key          = Augustus Genes
balloon hover = <b>$name</b> is a predicted gene spanning $ref from $start to $end. Click for more details.

[FgenesH]
feature      = gene:FGenesH_Monocots gene:FGenesH gene:FGenesH_Dicots
glyph        = gene
bgcolor      = green
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

[Blastn]
feature      = match:BLASTN
glyph        = segments
fgcolor      = red
height       = 8
key          = Blastn

[Blastx]
feature      = match:BLASTX
glyph        = segments
fgcolor      = magenta
key          = Blastx


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


