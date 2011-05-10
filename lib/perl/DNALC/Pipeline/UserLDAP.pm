package DNALC::Pipeline::UserLDAP;
use Net::LDAP ();
use Net::LDAP::Util qw(ldap_error_text);
use DNALC::Pipeline::Config ();

{
	my $cf;

	sub search {
		my ($class, $username) = @_;
		return unless $username;

		my $ldap = $class->get_server;
		return unless $ldap;

		my $msg = $ldap->bind;
		if ($msg->code) {
			print "Error binding: ", ldap_error_text($msg->code);
			return;
		}


		$cf ||= DNALC::Pipeline::Config->new->cf('LDAP');
		$msg = $ldap->search(
				base   => $cf->{BASE},
				filter => "(uid=$username)",
				attrs  => [ qw/uid sn givenName mail/ ],
			);
		if ($msg->code) {
			print STDERR "Error searching: ", ldap_error_text($msg->code), $/;
		}

		my $user = undef;
		if ($msg->count) {
			my $entry = $msg->shift_entry;
			$user = {
				username => $entry->get_value('uid'),
				name_first => $entry->get_value('givenName'),
				name_last => $entry->get_value('sn'),
				email => $entry->get_value('mail'),
			};
		}
		$ldap->unbind;

		$user;
	}

	sub auth {
		my ($class, $username, $pass) = @_;
		return unless $username;

		my $ldap = $class->get_server;
		return unless $ldap;

		my $msg = $ldap->bind('uid='. $username. ',ou=People,dc=iplantcollaborative,dc=org', password => $pass);
		if ($msg->code) {
			print "Error binding: ", ldap_error_text($msg->code);
			return;
		}

		$ldap->unbind;

		return 1;
	}

	sub get_server {
		$cf ||= DNALC::Pipeline::Config->new->cf('LDAP');

		my $ldap = Net::LDAP->new($cf->{SERVER}, version => 3)
			or die "$@";
	}
}

1;

__END__
package main;

use strict;
use warnings;
use Data::Dumper;

my $username = 'ghiban';
my $found = DNALC::Pipeline::UserLDAP->search( $username );
print "found: ", Dumper($found), $/;
