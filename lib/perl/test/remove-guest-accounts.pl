#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  remove-guest-accounts.pl
#
#        USAGE:  ./remove-guest-accounts.pl  
#
#  DESCRIPTION:  Removes guest accounts from DNA Subway
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  11/07/09 16:41:46
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Date::Calc qw/Today Delta_Days/;
use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::App::ProjectManager ();
use Data::Dumper;

$ENV{GMOD_ROOT} = '/usr/local/gmod';
my $cf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my ($y1, $m1, $d1) = Today();

my @users = DNALC::Pipeline::User->search_like(username => 'guest%');
for my $u (@users) {
	next if $u->username eq 'guest';
	next unless $u->created;
	my ($y2, $m2, $d2) = parse_datetime($u->created);
	my $dd = Delta_Days(($y2, $m2, $d2), ($y1, $m1, $d1));
	next if $dd < 2;
	print STDERR  $u, ' ', $u->username, ' ', $dd, $/;

	remove_projects($u);
	remove_apollo_files($u);
	drop_chadodb($u);

	# gbrowse db dir, reg: /var/www/html/gbrowse/databases/guest_u4pc1k9
	#last;
}

# returns (y, m, d) from a strings like: "%Y-%m-%d %H:%M:%S"
sub parse_datetime {
	my $str = shift;
	if ($str =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
		return ($1, $2, $3); 
	}
	return ();
}

sub remove_projects {

	my $u = shift;
	my @projects = DNALC::Pipeline::Project->search(user_id => $u->id);
	print STDERR  "------------PROJECTS OF USER ----", $u->username, $/;
	print STDERR  join (", ", @projects), $/;
	for my $p (@projects) {
		my $pm = DNALC::Pipeline::App::ProjectManager->new($p);
		# gbrowse dir/files
		# gmod conf
		my $organism_str = join('_', split /\s+/, $p->organism) . '_' . $p->common_name;

		my $cutils = DNALC::Pipeline::Chado::Utils->new(
					username => $u->username,
					organism_string => $organism_str,
					profile => $pm->chado_user_profile,
					gbrowse_template => $cf->{GBROWSE_TEMPLATE},
					gbrowse_confdir  => $cf->{GBROWSE_CONF_DIR},
				);
		my $gmod_conf_file = $cutils->gmod_conf_file($p->id);
		print STDERR  "p.$p ->", $gmod_conf_file, $/;

		#my $gbrowse_file = $cutils->create_gbrowse_conf($p->id, $cf->{GBROWSE_DB_DIR});

		my $gbrowse_file = $cutils->gbrowse_chado_conf($p->id);
		print STDERR  "p.$p =>", $gbrowse_file , $/;

		# project dir
		my $dir = $pm->work_dir;
		print STDERR  "p.$p DIR => ", $dir, $/;
		print STDERR  "----", $/;
	}
}

sub remove_apollo_files {
	my $u = shift;
	my $username = $u->username;
	my $apollo_dir = $cf->{APOLLO_USERCONF_DIR};
	my @files = grep {/$apollo_dir\/$username/} <$apollo_dir/*>;
	print STDERR Dumper( \@files ), $/;

	#http://pipeline-dev.dnalc.org/files/apollo/tmp/mouse_ear_cress_524:1-3400.jnlp
}

sub drop_chadodb {
	my $u = shift;

}
