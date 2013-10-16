#!/usr/bin/perl -w
use strict;
use Data::Dumper;

my (%desc);

my $usage = "cuffdiff_sort.pl PATH LABELS\n";
my $path   = shift or die $usage;
my $labels = shift or die $usage;

my @labels = split(',',$labels);

my @pairs;
my %pair;
for my $i (@labels) {
    for my $j (@labels) {
        my $pair = join '.', sort ($i,$j);
        next if $pair{$pair}++ || $i eq $j;
        push @pairs, [$i,$j];
    }
}

my $fdr = shift || 0.05;

open DEF, "cat $path/annotations/*.txt |" or die $!;
while (<DEF>) {
    chomp;
    my ($g,$l,$d) = split "\t";
    $g or next;
    $desc{$g}  = $d || '.';
}
close DEF;

open INDEX, ">$path/cuffdiff_out/summary.txt" or die $!;

my $idx;
for my $pair (@pairs) {
    $idx++;
    screen_file("$path/cuffdiff_out/gene_exp.diff",0,1,0,"$path/cuffdiff_out", "genes_$idx\_summary",0,@$pair);
    screen_file("$path/cuffdiff_out/isoform_exp.diff",0,1,0,"$path/cuffdiff_out", "transcripts_$idx\_summary",1,@$pair);
}

close INDEX;


sub format_p_val {
    my $p = shift;
    $p = sprintf("%.4f", $p) unless $p < 0.0001;
    $p = 1 if $p == 1;
    $p = 0 if $p == 0;
    return $p;
}

sub screen_file {
    my $infile = shift;
    my $sortf  = shift;
    my $maxp   = shift;
    my $minfold = shift;
    my $outpath = shift;
    my $outfile = shift;
    my $transcript = shift;
    my $s1 = shift;
    my $s2 = shift;

    my ($index,$sorted_by);
    if ($transcript) {
	$index = $sortf ? '-k6nr' : '-k8nr';
    }
    else {
	$index = $sortf ? '-k5nr' : '-k7nr';
    }
    
    if ($outfile =~ /fold/) {
	$sorted_by = 'fold change';
    }
    else {
	$sorted_by = 'total expression (FPKM)'
    }

    $outfile = join('/',$outpath,$outfile);
    

    my @header = $transcript ? ('Transcript') : ();
    push @header, ('Gene','Alias','Fold Change', 'Direction', 'Total FPKM', 'Q-Value', 'Description');

    open TXT,  ">$outfile.csv"  or die $!;
    open HTML, ">$outfile.html" or die $!; 

    chomp(my $file_base = `basename $outfile.csv .csv`);
    print INDEX join("\t","$file_base.csv","$file_base.html",$s1,$s2), "\n";

    print TXT join(',', @header), "\n";
    close TXT;
    open  TXT , "| sort $index | perl -pe 's/\t/,/g' >>$outfile.csv";

    open IN, $infile or die "Could not open $infile for writing: $!";
    my ($out,@out);
    while (<IN>) {
	chomp;
	next if /test_id/;
	next unless /OK/;
      
	my @line = split "\t";

	next unless $line[4] eq $s1 || $line[4] eq $s2;
	next unless $line[5] eq $s1 || $line[5] eq $s2;

	my ($gene,$locus) = @line[1,2];
	$locus = '' if $line[2] eq $gene;
	$locus = '' if $locus eq '-';
	$gene =~ s/,\S+//;
	my $direction =$line[7] > $line[8] ? 'DOWN' : 'UP';
	if ($line[4] ne $s1) {
	    $direction = $direction eq 'UP' ? 'DOWN' : 'UP';
	}

	my ($hi,$lo) = sort { $b <=> $a } $line[7], $line[8];
	next unless $hi && $lo;
	my $fold_change = $hi/$lo;
	next if $minfold && $fold_change < $minfold;
	my $p_val = format_p_val($line[12]);
	next if $maxp && $p_val > $maxp;
	$p_val = "RED:$p_val" if $p_val <= $fdr;
	my $out = $transcript ? "GENE:$line[0]\t" : '';

	$out .= join ("\t","GENE:$gene",$locus,sprintf("%.2f",$fold_change),$direction,sprintf("%.2f",($hi+$lo)),$p_val);
	print "NO p value! $out\n" unless $p_val;

	if (defined $desc{$gene}) {
	    $out .= "\t$desc{$gene}\n";
	}
	elsif ($gene =~ /XLOC/) {
	    $out .= "\tCufflinks novel gene\n";
	}
	else {
	    $out .= "\t\n";
	}

	# we will be csv
	$out =~ s/,/;/g;
	print TXT $out;
    }
    close IN;
    close TXT;


    open TXT, "<$outfile.csv" or die $!;
    
    my $thing  = $transcript ? 'Transcripts' : 'Genes';

    chomp(my $export = `basename $outfile.csv`);
    print HTML <<"END";
<html>
 <head>
  <title>Cuffdiff data summary</title>
  <link type="text/css" rel="stylesheet" href="/css/cdtables.css" />
  <script src="//ajax.googleapis.com/ajax/libs/jquery/2.0.0/jquery.min.js"></script>
  <!-- DataTables CSS -->
  <link rel="stylesheet" type="text/css" href="http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.4/css/jquery.dataTables.css">
  <!-- DataTables -->
  <script type="text/javascript" charset="utf8" src="http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.4/jquery.dataTables.min.js"></script>
 </head>
 <body>
  <div id="export-csv">
   <a href="$export"><img src="/images/v2/csv.jpg" align="middle"> Export data to spreadsheet</a>
  </div>
  <h2>$thing sorted by $sorted_by</h2>
  <table id="cd_table" cellspacing=0>
  <thead>
END
;

    my $first = 1;
    my $ehref = 'http://ensemblgenomes.org/search/eg/';
    while (<TXT>) {
	chomp;
	if ($first) {
	    $_ = qq(   <tr style="background:gainsboro">\n    <th>$_</th>\n   </tr>);
	    s!,!</th>\n    <th>!g;
	    $_ .= "\n   </thead>\n   <tbody>\n";
	    undef $first;
	}
	else {
	    s/GENE://g if /XLOC|CUFF/;
	    $_ = "   <tr>\n    <td>$_</td>\n  </tr>\n";
	    s!,!</td>\n    <td>!g;
	    s!RED:([^,]+)!<span style="color:red">$1</span>!;
	}
	print HTML $_;
    }
   
    my $column = $thing eq 'Genes' ? 4 : 5; 
    print HTML <<"END";
   </tbody>
  </table>
  <script language="Javascript" type="text/javascript">
    \$(document).ready(function() {
      var table = \$("#cd_table").dataTable({
              //"aoColumnDefs": [
              //    { "bSortable": false, "aTargets": [ 2, 3 ] },
              //],
              "bPaginate": false,
              "sScrollY": "250px",
              "sDom": "frtiS",
              "bDeferRender": true,
	  				 });
          // sort by column $column (fpkm) descending on load
	  	  table.fnSort( [ [ $column, 'desc'] ] );
 
      });
  </script>
 </body>
</html>
END
;

    close TXT;
    close HTML;
    
    system "perl -i -pe 's/GENE\:|RED\://g' $outfile.csv";
    system qq(perl -i -pe 's!GENE:([^<]+)!<a href="$ehref\$1" target="_blank">\$1</a>!g' $outfile.html);
}

exit 0;



