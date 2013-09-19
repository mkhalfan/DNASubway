package iPlant::FoundationalAPI::Auth;

use warnings;
use strict;

use iPlant::FoundationalAPI::Constants ':all';
use base 'iPlant::FoundationalAPI::Base';
use MIME::Base64;
use Carp qw/carp/;
use Data::Dumper;

=head1 NAME

iPlant::FoundationalAPI::Auth - The great new iPlant::FoundationalAPI::Auth!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

my $TRANSPORT = 'https';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use iPlant::FoundationalAPI::Auth;

    my $foo = iPlant::FoundationalAPI::Auth->new();
    ...

=head1 FUNCTIONS

=head2 new

=cut

sub new {
	my ($proto, $args) = @_;
	my $class = ref($proto) || $proto;
	
	my $self  = { map {$_ => $args->{$_}} grep {/(?:user|token|password|hostname|lifetime|debug)/} keys %$args};
	
	bless($self, $class);
	
	if ($self->{user} && $self->{password} && !$self->{token}) {
		# hit auth service for a new token
		my $newToken = $self->auth_post_token();
		print STDERR "Issued-Token: ", $newToken, "\n" if $newToken && $self->debug;
		$self->{token} = $newToken;
		delete $self->{password};
	}
	elsif ($self->{user} && $self->{token}) {
		unless ($self->is_token_valid) {
			carp "Authentication failed...\n";
			return;
		}
		else {
			print STDERR  "Token validated successfully", $/ if $self->debug;
		}
	}

	return $self;
}

sub validate_auth {
	my ($self) = @_;
	
	return 0;
}


sub auth_post_token {
	
	# Retrieve a token in user mode
	my $self = shift;
	my $renew = shift;

	if ($renew && $self->{password}) {
		print STDERR  "Revalidating token...", $/ if $self->debug;
	}

	my $ua = $self->_setup_user_agent;
	$ua->default_header( Authorization => 'Basic ' . _encode_credentials($self->user, $self->password) );
	
	my $auth_ep = $self->_get_end_point;
	my $url = "https://" . $self->hostname . "/$auth_ep/";

	my $content = [];

	if ($renew) {
		$url .= "renew";
		push @$content, token => $self->token;
	}

	if ($self->{lifetime}) {
		push @$content, lifetime => $self->{lifetime};
	}
	
	print STDERR  '..::Auth::auth_post_token: ', $url, $/ if $self->debug;

# 	my $req = HTTP::Request->new(POST => $url);
# 	if (@$content) {
# 		#print STDERR Dumper( \$content), $/ if $self->debug;
# 		#print STDERR  "FIXME: see how to submit params.. at ", __LINE__, $/;
# 		$req->content($content);
# 	}
# 	my $res = $ua->request($req);

	my $res = $ua->post( $url, $content);
	
	my $message;
	my $mref;
	my $json = JSON::XS->new->allow_nonref;

	if ($res->is_success) {
		$message = $res->content;
		$mref = eval {$json->decode( $message );};
		if ($mref) {
			if ($mref->{status} eq 'success' && defined($mref->{'result'}->{'token'})) {
				$self->{token_expires} = $mref->{'result'}->{expires};
				return $mref->{'result'}->{'token'};
			}
			else {
				print STDERR  $mref->{'status'}, ": ", $mref->{'message'}, $/ if $self->debug;
				return kExitError;
			}
		}
		else {
			print STDERR  $message, $/ if $self->debug;
			return kExitError;
		}
	} else {
		print STDERR (caller(0))[3], " ", $res->status_line, "\n" if $self->debug;
		return undef;
	}

}

=head2 is_token_valid

  Checks is the token hasn't expired or not.
  It returns the # of seconds till the expiration of the token.
  This info can be used to reissue a token or to revalidate the token that
  will soon expire.

=cut

sub is_token_valid {
	my ($self) = shift;
	
	unless ($self->token_expiration) {
		carp "Can't tell token expiration...\n" if $self->debug;

		my $ua = $self->_setup_user_agent;
		$ua->default_header( Authorization => 'Basic ' . _encode_credentials($self->user, $self->token) );
	
		my $auth_ep = $self->_get_end_point;
		my $url = "https://" . $self->hostname . "/$auth_ep/";

		print STDERR  '..::Auth::is_token_valid: ', $url, $/ if $self->debug;

		my $req = HTTP::Request->new(GET => $url);
		my $res = $ua->request($req);
	
		my $message;
		my $mref;
		my $json = JSON::XS->new->allow_nonref;

		if ($res->is_success) {
			$message = $res->content;
			$mref = eval {$json->decode( $message );};
			if ($mref) {
				if ($mref->{status} eq 'success') {
					return 1;
				}
				else {
					return;
				}
			}
			else {
				print STDERR  $message, $/ if $self->debug;
				return;
			}
		} else {
			print STDERR (caller(0))[3], " ", $res->status_line, "\n" if $self->debug;
			return;
		}
	}

	my $delta = $self->token_expiration - time();
	print STDERR "DELTA is_token_valid: ", $delta, $/ if $self->debug;

	return $delta > 0 ? $delta : 0;
}

=head2 token_expiration

  Returns the timestamp of when the token will expire, if available.

=cut

sub token_expiration {
	my ($self) = shift;
	return $self->{token_expires};
}


sub _encode_credentials {
	
	# u is always an iPlant username
	# p can be either a password or RSA encrypted token
	
	my ($u, $p) = @_;
	encode_base64("$u:$p");
}


=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Cornel Ghiban, C<< <ghiban at cshl.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-iplant-foundationalapi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=iPlant-FoundationalAPI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc iPlant::FoundationalAPI::Auth


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=iPlant-FoundationalAPI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/iPlant-FoundationalAPI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/iPlant-FoundationalAPI>

=item * Search CPAN

L<http://search.cpan.org/dist/iPlant-FoundationalAPI/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2011 Cornel Ghiban.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of iPlant::FoundationalAPI::Auth
