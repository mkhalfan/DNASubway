
plugins = AttributeHiliter BatchDumper FastaDumper

show sources  = 0
cache time = 0 

# Default glyph settings
glyph       = generic
height      = 8
bgcolor     = cyan
fgcolor     = cyan
label density = 25
bump density  = 10000

# where to link to when user clicks in detailed view
link          = AUTO

# what image widths to offer
image widths  = 640 800 1024

# default width of detailed view (pixels)
default width = 800
default tracks = Augustus FGenesH tRNA Snap usergenes Repeats Blastx Blastn Blastn_user Blastx_user

# max and default segment sizes for detailed view
max segment     = 100000
default segment = 10000

# zoom levels
zoom levels    = 100 200 1000 2000 5000 10000 25000 50000 100000 150000

# colors of the overview, detailed map and key
overview bgcolor = lightgrey
detailed bgcolor = lightgoldenrodyellow
key bgcolor      = beige

# examples to show in the introduction
#examples = chr1:1000..10000

# "automatic" classes to try when an unqualified identifier is given
automatic classes = gene

search_instructions = &nbsp;
navigation_instructions = &nbsp;

language = en
### HTML TO INSERT AT VARIOUS STRATEGIC LOCATIONS ###
# inside the <head></head> section
#head = <script src="/gbrowse/js/geneDetails.js" type="text/javascript"></script>
head = 

# at the top...
header =

# a footer
footer = 

# Default glyph settings
[TRACK DEFAULTS]
glyph       = generic
height      = 8
bgcolor     = cyan
fgcolor     = cyan
label density = 25
bump density  = 10000
link           =AUTO
# database    = test_db
balloon hover = <b>$name</b> is a $type spanning $ref from $start to $end. Click for more options.
balloon click width = 500
balloon click = url:/project/gene_options?ref=$ref;name=$name;start=$start;end=$end;id=$id;gb=2


