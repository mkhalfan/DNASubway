package DNALC::Pipeline::Utils;
use strict;
use warnings;

use Exporter;
use Time::Local ();
use HTML::Entities ();
use List::Util qw();


use vars qw(
            $VERSION
            @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
            $AUTOLOAD
           );
@ISA = qw(Exporter);
@EXPORT_OK = qw(
                    array_diff
                    clean_query
                    clean_string
                    date
                    date2epoch
                    debug_cdbi
                    debug_sql
                    escape_js
                    isin
                    highlight_code
                    html_escape
                    md5_salt
                    month_name
                    nicebytes
                    nicenumbers
                    path2args
                    percent
                    random_string
                    round
                    sec2time
                    split_terms
                    time2sec
                    text_grid
                    text_to_html
                    uri2args
                   );
%EXPORT_TAGS = ( 'all' => \@EXPORT_OK );


sub random_string {
    my $min = shift || 4; $min =~ /\D/ and $min = 4;
    my $max = shift || 8; $max !~ /\D/ && $max >= $min or $max = $min+5;
    #my @chars = ('.', '/', 0..9, 'A'..'Z', 'a'..'z');
	#my @chars = ( 0..9, 'A'..'Z', 'a'..'z', 0..9);
    my @chars = ( 0..9, 'A'..'Z', 'A'..'Z', 0..9);
    my $string = '';
	$string .= $chars[rand 64] for( 1 .. $min + rand($max-$min) );
	$string;
}

sub md5_salt {
	return '$1$' . random_string(8,8) . '$';
}

sub nicenumbers {
    my ($no, $digits) = @_;
    $no = reverse $no;
    $no =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    $no = scalar reverse $no;
    $no =~ s/\.(\d{$digits})\d+/\.$1/g if $digits;
	$no =~ s/\.0+(?=\D|$)//g;
    return $no;
}

sub nicebytes {
    my $bytes = shift || 0;
    return "$bytes B" if $bytes < 1024;
    my $kilo = $bytes / 1024;
    return sprintf "%02.02f KB", $kilo if $kilo < 1024;
    my $mega = $kilo / 1024;
    return sprintf "%02.02f MB", $mega if $mega < 1024;
    my $giga = $mega / 1024;
    return sprintf "%02.02f GB", $giga;
}

sub isin {
    my ($term, @array) = @_;
    foreach(@array) { return 1 if $_ eq $term }
    return 0;
}

sub escape_js {
    local $_ = shift;
    s/'/\\'/sg;
    s{\r?\n}{\\r\\n}sg;
    $_;
}

sub time2sec {
    my @parts = reverse split(':', shift);
    my $sec = 0;
    my $multi = 1;
    while(my $k = shift @parts) {
        $sec += $k*$multi;
        $multi *= 60;
    }
    return $sec;
}

sub sec2time {
    my $s = shift;
    my $days = shift || 0;
    return sprintf "00:00:%02d", $s if $s < 60;

    my $m = $s / 60; $s = $s % 60;
    return sprintf "00:%02d:%02d", $m, $s if $m < 60;

    my $h = $m /  60; $m %= 60;

    if ($days) {
        return sprintf "%02d:%02d:%02d", $h, $m, $s if $h < 24;
        my $d = $h / 24; $h %= 24;
        return sprintf "%d:%02d:%02d:%02d", $d, $h, $m, $s;
    } else {
        return sprintf "%02d:%02d:%02d", $h, $m, $s;
    }
}

sub date {
    my $months_short = {
    	'01' => 'Jan', '02' => 'Feb', '03' => 'Mar', '04' => 'Apr',
    	'05' => 'May', '06' => 'Jun', '07' => 'Jul', '08' => 'Aug',
    	'09' => 'Sep', '10' => 'Oct', '11' => 'Nov', '12' => 'Dec',
    };
    my $months = {
    	'01' => 'January', '02' => 'February', '03' => 'March',
    	'04' => 'April',   '05' => 'May',      '06' => 'June',
    	'07' => 'July',    '08' => 'August',   '09' => 'September',
    	'10' => 'October', '11' => 'November', '12' => 'December',
    };
    my $time = shift || time();

    #   0    1    2     3     4    5     6     7     8
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    my $date = {
    	'year'  => $year+1900,
    	'month' => sprintf("%02d", $mon+1),
    	'day'   => sprintf("%02d", $mday),
    	'hour'  => sprintf("%02d", $hour),
    	'min'   => sprintf("%02d", $min),
    	'sec'   => sprintf("%02d", $sec),
    };
    $date->{month_name}       = $months->{$date->{month}};
    $date->{month_name_short} = $months_short->{$date->{month}};
    return $date;
}

sub html_escape {
    my ($text) = shift || return '';
    my %html_escape = ('&' => '&amp;', '>'=>'&gt;', '<'=>'&lt;', '"'=>'&quot;');
    my $html_escape = join('', keys %html_escape);
    $text =~ s/([$html_escape])/$html_escape{$1}/mgoe;
    return $text;
}    

sub month_name {
    my $month = shift || return '';
    return '' unless $month =~ /^\d+$/;
    return '???' unless $month > 0 && $month < 13;
    my @months = qw( NULL
    		Ianuarie  Februarie  Martie      Aprilie    Mai       Iunie
    		Iulie     August     Septembrie  Octombrie  Noiembrie Decembrie
    );
    return $months[$month];
}

sub path2args {
    my $margs = {};
    my $path = shift || return $margs;

    ### grab key/value pairs
    while ($path =~ s{/([^/]+)/([^/]+)}{}) {
        my ($key, $val) = ($1,$2);
        for ($key, $val) {
            $_ =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        }
        push @{$margs->{$key}}, $val;
    }
    ### normalize single values
    foreach (keys %{$margs}) {
        if (@{$margs->{$_}} == 1) {
            $margs->{$_} = $margs->{$_}[0];
        }
    }

    return $margs;
}

sub uri2args {
    my $margs = {};
    my $path = shift || return $margs;

    ### cleanup $path
    for ($path) {
        s{/+}{/}sg;
        s{^/}{}s;
        s{/$}{}s;
    }

    ### extract key,value pairs
    foreach (split('/', $path)) {
        $_ =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        my ($key, $val) = split(/[:=,]/, $_,2);

        push @{$margs->{$key}}, $val if defined $val;
    }

    ### normalize single values
    foreach (keys %{$margs}) {
        if (@{$margs->{$_}} == 1) {
            $margs->{$_} = $margs->{$_}[0];
        }
    }

    return $margs;
}

sub percent {
    my ($qty, $total, $precision) = @_;
    $qty       ||= 0;
    $total     ||= 100;
    $precision ||= '02';

    return $total && $qty
     	? sprintf "%.${precision}f", $qty*100/$total
     	: 0;
}

sub array_diff {
    my ($a1,$a2) = @_;
    my %h;
    @h{@$a1} = @$a1; 
    my @res = ();
    foreach (@$a2) {
        push @res, $_ unless exists $h{$_}
    }    
    @res
}

sub round {
    local $_ = shift;
    int($_ + .5)
}

#=================================
# ARGUMENTS: ($query, @args)
#-----------------
sub debug_sql {
    my ($query, @args) = @_;
    $query =~ s/\s+/ /gs;
    my $toret = '';
    foreach (@args) {
        s/'/\\'/sg;
        $query =~ s/^(.+?)\?//;
        $toret .= "$1'$_'";
    }
    $toret .= $query;
    return $toret;
}

#=================================
# ARGUMENTS: ($cdbi_object [, $separator])
#-----------------
sub debug_cdbi {
	my ($o, $sep) = @_;
	$sep ||= ' ';
	return join $sep, map { "[$_: " . $o->$_ . ']' } sort $o->columns;
};

sub date2epoch {
	my $date = shift;

	# fallback to now
	return time unless $date;

	my ($year, $mon, $mday, $hour, $min, $sec) = split(/\D+/, $date);
	# get back to localtime values
	$year -= 1900;
	$mon  -= 1;

	# allow "date only"
	$sec  ||= 0;
	$min  ||= 0;
	$hour ||= 0;

	return Time::Local::timelocal($sec, $min, $hour, $mday, $mon, $year);
}

#=================================
# ARGUMENTS: ($string_to_clean)
#-----------------
sub clean_query {
	local $_ = "@_";
	s/\s+/ /sg;
	s/^\s+//s;
	s/\s+$//s;
	$_;
}
*clean_string = \&clean_query;

#=================================
# ARGUMENTS: ($string(s)_to_clean)
#-----------------
sub text_to_html {
	local $" = '';
	local $_ = html_escape(HTML::Entities::decode_entities("@_"));
	s/\r//sg;
	s/[ \t]+/ /sg;
	s/\n +/\n/sg;
	s/[\n]{3,}/\n\n/sg;
	s{^\s*}{<p>}s;
	s{\s*$}{</p>}s;
	s{\n\n}{</p><p>}sg;
	s{^(?!<)}{<br />}mg;
	s{\n(?!<)}{ }sg;
	s{\n(?=<)}{}sg;
	$_;
}

#=================================
# ARGUMENTS: ($string_to_clean)
#-----------------
sub split_terms {
	local $_ = clean_string("@_");
	my @terms = ();
	push @terms, clean_string($1) while s/"([^"]+)"//s;
	s/"+/ /g;
	push @terms, split /\s+/;
	grep { $_ ne '' } @terms;
}

#=================================
# ARGUMENTS: (headers => [], formats => [], grid => [], separator => ' ')
#-----------------
sub text_grid {
    my (%opt) = @_;
    my @headers = @{$opt{headers}};
    my @formats = @{$opt{formats}};
    my @grid    = @{$opt{data}};
    my $separator = $opt{separator} || ' | ';
    return q{} if !@grid;

    # compute max column size
    my @size;
    foreach my $idx (0 .. $#{$grid[0]}) {
        push @size, List::Util::max(map { length $_->[$idx] } \@headers, @grid);
    }

    # prepare output template
    my $template;
    foreach my $idx (0 .. $#size) {
        my $col = $formats[$idx] || '%s';
        if ($idx < $#size) {
            $col =~ s/ ^ (%-?) /$1$size[$idx]/xms;
        }
        $template .= $separator . $col;
    }
    $template =~ s{ ^ \Q$separator\E }{}xms;

    my $ret = q{};

    # headers available?
    if (@headers) {
        my $htmpl = join $separator, map { "%-${_}s" } @size;
        $ret .= sprintf $htmpl . "\n", map {tr/_/ /;$_} @headers;
    }
    my $sep_line = '-' x (List::Util::sum(@size) + length($separator) * scalar($#size)) . "\n";

    $ret .= $sep_line;
    $ret .= sprintf $template . "\n", @$_ for @grid;
    $ret .= $sep_line;
    return $ret;
}


1;

__END__
