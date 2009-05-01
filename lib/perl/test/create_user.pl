#!/usr/bin/perl -w

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Group ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::Chado::Utils ();
use Data::Dumper;

use strict;

#-----------------------------------------------------------------------------
my ($users_group) = DNALC::Pipeline::Group->search(group_name => 'user');
#-----------------------------------------------------------------------------

my $username = $ARGV[0] || random_string(4, 15);

print STDERR "Trying to create user = ", $username, $/;
my $pwd = random_string(4, 15);

my $u = DNALC::Pipeline::User->create({
			username => $username,
			password => $pwd,
			email => 'ghiban@cshl.edu',
			name_first => 'Cornel',
			name_last => 'Ghiban'
		});

unless ($@) {
	$u->add_to_group($users_group);
	$u->dbi_commit;
}

print STDERR  "user=", $u->username, $/;
print STDERR  "uid=", $u->id, $/;

#test passwd
if ($u->password_valid($pwd)) {
	#print STDERR  "User groups: ", Dumper($u->groups), $/;
	#print STDERR  'Login OK', $/;
}
else {
	print STDERR  'login failed', $/;
}


my $cf = DNALC::Pipeline::Config->new;
my $pcf = $cf->cf('PIPELINE');
#create user db/env

my %args = (
  'username'  => $u->username,
  'dumppath'  => $pcf->{GMOD_DUMPFILE},
  'profile'   => $pcf->{GMOD_PROFILE},
);

my $cutils = DNALC::Pipeline::Chado::Utils->new(%args);

my $QUIET = 1;
$cutils->create_db($QUIET);

exit 0;


