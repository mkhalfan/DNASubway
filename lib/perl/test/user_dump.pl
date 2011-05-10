#!/usr/bin/perl

use common::sense;
use DNALC::Pipeline::User ();
use DNALC::Pipeline::UserProfile ();


my @u_cols = qw/id username name_first name_last email login_count created login_last/;
my @p_cols = ('Country', 'Zipcode', 'Gender', 'Status/Occupation', 'How did you hear about us?');

#my $uu = DNALC::Pipeline::User-> {order_by => 'login_count desc'});
my $uu = DNALC::Pipeline::User->retrieve_from_sql(qq{
		login_last is not null
		order by login_count desc
	});
#print $uu, $/;
print '#', join "\t", (@u_cols, @p_cols), "\n";
while (my $u = $uu->next) {
	#my $inst = DNALC::Pipeline::UserProfile->get_user_institution($u->id) || '-';
	my $up = $u->profile;
	#print join "\t", $u->id, $u->username, $u->name_first, $u->name_last,
	#	$u->email, $u->login_count, $u->created, $u->login_last, $inst;

	#print join "\t", $u->id, $u->username, $u->name_first, $u->name_last, 
	#	$up->{Country} || '-', $up->{Zipcode} || '-', $up->{Gender} || '-';
	#	$u->email, $u->login_count, $u->created, $u->login_last, $inst;
	my @data = ();
	for my $col (@u_cols) {
		push @data, $u->$col || '-';
	}
	for my $col (@p_cols) {
		push @data, defined $up->{$col} ? $up->{$col} : '-';
	}
	print join ("\t", @data), "\n";
}
