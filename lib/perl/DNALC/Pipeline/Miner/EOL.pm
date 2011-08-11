package DNALC::Pipeline::Miner::EOL;

use URI::Escape;
use Data::Dumper;
use HTTP::Tiny ();
use JSON::XS ();
use utf8;

# ping: http://www.eol.org/api/docs/ping
# pages: http://www.eol.org/api/docs/pages
# search: http://www.eol.org/api/docs/search
# 
{
	# globals
	my $api_server = "http://www.eol.org/api";
	my $version = "1.0";
	my $key = '9ab98ff1de0ef6115e3d004f8df764032e5fe48d';

	sub new {
			return bless {}, __PACKAGE__;
	}

	sub get {
		my ($self, $uri) = @_;
		my $response = HTTP::Tiny->new->get($uri);
		if ($response->{success}) {
			 if (length $response->{content}) {
				my $js = JSON::XS->new->utf8;
				my $scalar = $js->decode($response->{content});
				return $scalar;
			}
			else {
					return {};
			}
		}
		else {
			print STDERR "NOT SUCCESS:\n$response->{status} $response->{reason}\n";
			return {error => {status => $response->{status}, reason => $response->{reason}}};
		}
	}

	sub ping_ok {
		my ($self) = @_;
		my $ping_uri = "http://www.eol.org/api/ping.json";
		my $ping = $self->get($ping_uri);

		return $ping->{response}->{message} =~ /success/i;
	}

	sub build_uri {
		my ($class, $type, $query) = @_;

		$query =~ s/\.//g; # remove dot
		my $uri = "$api_server/$type/$version/" . uri_escape( $query ) . ".json";
		$uri .= "?key=$key" if $key;

		return $uri;
	}

	sub search {
		my ($self, $query) = @_;
		my $s_uri = $self->build_uri("search", $query);
		print STDERR "Search: ", $s_uri, $/;

		my $s_json = $self->get($s_uri);
		return $s_json;
	}
}

__END__
package main;

use common::sense;

sub main {
	my $eol = DNALC::Pipeline::Miner::EOL->new;
	if ($eol->ping_ok()) {
		print STDERR "Ping OK\n";
		my $s = $eol->search("Homo sapiens");
		if ($s && defined $s->{totalResults} && $s->{totalResults} > 0) {
			for (@{$s->{results}}) {
				print $_->{id}, " ", $_->{title}, $_->{link}, $/;
			}
			return;
			#---------------------------------------------
			my $resource = $s->{results}->[1];
			print Dumper($resource);
			my $res_uri = $eol->build_uri("pages", $resource->{id});
			print "Object: ", $res_uri, $/;
			$res_uri .= '?common_names=0&details=0&images=0&text=0&videos=0&format=json';
			print "Object: ", $res_uri, $/;

			my $object = $eol->get($res_uri);
			if ($object) {
				delete $object->{vernacularNames};
				print Dumper ($object);
			}
		}
		#print Dumper($s);
		
	}
	else {
		print "EOL API not responding..\n";
	}
	return;
	#my $uri = build_uri('search', 'Homo sapiens');
	#print $uri, $/;
	
}

main();
