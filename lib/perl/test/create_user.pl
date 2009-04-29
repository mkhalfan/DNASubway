#!/usr/bin/perl -w

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Group ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
use Data::Dumper;

use strict;

#-----------------------------------------------------------------------------
my ($users_group) = DNALC::Pipeline::Group->search(group_name => 'user');

#-----------------------------------------------------------------------------

my $pwd = random_string(4, 15);

my $u = DNALC::Pipeline::User->create({
			username => random_string(4, 15),
			password => $pwd,
			email => 'ghiban@cshl.edu',
			name_first => 'Cornel',
			name_last => 'Ghiban'
		});

unless ($@) {
	$u->add_to_group($users_group);
	$u->dbi_commit;
}

print STDERR  "u=", $u->username, $/;

#test passwd
if ($u->password_valid($pwd)) {
	print STDERR  "User groups: ", Dumper($u->groups), $/;
	print STDERR  'Login OK', $/;
}
else {
	print STDERR  'login failed', $/;
}

#create user db/env
my $cf = DNALC::Pipeline::Config->new;
my $exe_path = $cf->cf('PIPELINE')->{EXE_PATH};
print STDERR  "EXE_PATH: ", $exe_path, $/;

exit 0;


