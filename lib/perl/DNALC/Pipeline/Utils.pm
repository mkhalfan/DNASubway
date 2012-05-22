package DNALC::Pipeline::Utils;
use strict;
use warnings;

use Exporter;
use Time::Local ();
use HTML::Entities ();
use List::Util qw();
use Algorithm::Diff qw(LCS);

use vars qw(
            $VERSION
            @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
            $AUTOLOAD
           );
@ISA = qw(Exporter);
@EXPORT_OK = qw(
					break_long_text
                    clean_query
                    isin
					lcs_name
					nicebasepairs
                    random_string
                    uri2args
                   );
%EXPORT_TAGS = ( 'all' => \@EXPORT_OK );


sub random_string {
    my $min = shift || 4; $min =~ /\D/ and $min = 4;
    my $max = shift || 8; $max !~ /\D/ && $max >= $min or $max = $min+5;
    my @chars = ( 0..9, 'A'..'Z', 'A'..'Z', 0..9);
    my $string = '';
	$string .= $chars[rand 64] for( 1 .. $min + rand($max-$min) );
	$string;
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

sub isin {
    my ($term, @array) = @_;
    foreach(@array) { return 1 if $_ eq $term }
    return 0;
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

# it returns the LCS base on the given two strings
# if theere are more then $x (=3) diffs, is concatenates the input strings
sub lcs_name {
	my ($a, $b, $x) = @_;
	$x ||= 2;

    my @f = split(//, $a);
    my @r = split(//, $b);
    my @common = LCS( \@f, \@r );
    if (!@common || @common < @f - $x) {
        return join('_', $a, $b);
    }
	my $name = join('', @common);
	$name =~ s/[=_-]+$//;
    
	return $name;
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
