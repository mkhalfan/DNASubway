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
					break_long_text
                    clean_query
                    debug_cdbi
                    escape_js
                    isin
                    html_escape
                    md5_salt
					nicebasepairs
                    nicebytes
                    nicenumbers
                    path2args
                    random_string
                    round
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

sub nicebasepairs {
    my $bytes = shift || 0;
    return "$bytes b" if $bytes < 1000;
    my $kilo = $bytes / 1000;
    return sprintf "%02.02f kb", $kilo if $kilo < 1000;
    my $mega = $kilo / 1000;
    return sprintf "%02.02f mb", $mega if $mega < 1000;
    my $giga = $mega / 1000;
    return sprintf "%02.02f gb", $giga;
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

sub html_escape {
    my ($text) = shift || return '';
    my %html_escape = ('&' => '&amp;', '>'=>'&gt;', '<'=>'&lt;', '"'=>'&quot;');
    my $html_escape = join('', keys %html_escape);
    $text =~ s/([$html_escape])/$html_escape{$1}/mgoe;
    return $text;
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


sub break_long_text {
	my ($text, $maxlen) = @_;

	$maxlen ||= 50;
	$text =~ s/\S{$maxlen}/$& /sg;
	return $text;

	my @long_words = grep {length $_ > $maxlen} split /\W+/, $text;

	for my $lw (@long_words) {
		my @parts = split //, $lw;
		my $new_word = '';
		while (@parts) {
			$new_word .= join ('', splice(@parts, 0, $maxlen)) . ' ';
		}
		$new_word =~ s/\s+$//;
		$text =~ s/$lw/$new_word/;
	}
	$text;
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

1;

__END__
