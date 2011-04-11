#!perl

use common::sense;
use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_text);
use DNALC::Pipeline::User;
use Data::Dumper;

#ldapsearch -z 0 -S uid -LLL -x -h ldap.iplantcollaborative.org -b "ou=People,dc=iplantcollaborative,dc=org" "(uid=*)" uid sn givenName mail o|
my $ls = Net::LDAP->new("ldap.iplantcollaborative.org", version => 3) or die "$@";
#print $ls, $/;
#my $dn = "dc=cshl,dc=edu";
my $msg = $ls->bind;

if ($msg->code) {
	print "Error binding: ", ldap_error_text($msg->code);
	exit 1;
}

# get top 500 ldap users in one search
my $users = search_ldap_users();
my $conflicts = get_conflicts($users);
#print Dumper $users, $/;
print scalar (keys %$conflicts), $/;
#print  "@{$conflicts}", $/;

for my $uid (sort {$a cmp $b} keys %$conflicts) {
#for my $uid (keys %$conflicts) {
	#print Dumper $conflicts->{$uid}, $/;
	my $dnas = $conflicts->{$uid}->{dnas};
	my $ipc  = $conflicts->{$uid}->{ipc};
	next if lc $dnas->email eq lc $ipc->{mail} && lc $dnas->name_last eq lc $ipc->{sn};
	my $proj_cnt = DNALC::Pipeline::MasterProject->search(user_id => $dnas->id)->count;
	print $uid, " [", $proj_cnt, "/", $dnas->login_last || 'not set', "]", $/;
	print "\tdnas: ", join (",", $dnas->email, $dnas->name_last, $dnas->name_first), $/;
	print "\tipc:  ", join (",", $ipc->{mail}, $ipc->{sn}, $ipc->{givenName}), $/;
	print "\n";
}

#print scalar keys %$users, $/;

#---------------------

sub search_ldap_users {
	my ($uid)  = @_;
	$uid ||= '*';
	my %data = ();

	my $msg = $ls->search( 
			base   => "ou=People,dc=iplantcollaborative,dc=org",
			filter => "(uid=$uid)",
			#sizelimit => 100,
			attrs => [ qw/uid sn givenName mail/ ],
		);
	if ($msg->code) {
		print "Error searching: ", ldap_error_text($msg->code);
	}
	if ($msg->count) {
		while( my $entry = $msg->shift_entry) {
			my $uid = $entry->get_value('uid');
			my %entry = ();
			foreach my $attr ($entry->attributes) {
				foreach my $value ($entry->get_value($attr)) {
					#print $attr, ": ", $value, "\n";
					$entry{$attr} = $value;
				}
			}
			$data{$uid} = \%entry;
		}
	}
	return %data ? \%data : undef;
}

sub get_conflicts {
	my ($ldap_users) = shift;
	my $conflicts;

	my $dnas_users = DNALC::Pipeline::User->retrieve_all;

	while (my $u = $dnas_users->next) {
		my $username = $u->username;
		next if $username =~ /^guest_/;

		if (exists $ldap_users->{$username}) {
			$conflicts->{$username} = { ipc => $ldap_users->{$username}, dnas => $u};
		}
		else {
			my $ldap_user = search_ldap_users(lc $username);
			if ($ldap_user) {
				$conflicts->{$username} = { ipc => $ldap_user->{lc $username}, dnas => $u};
			}
		}
	}
	return $conflicts;
}
