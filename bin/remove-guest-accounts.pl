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

use lib '/var/www/lib/perl';

use common::sense;

use Date::Calc qw/Today Delta_Days/;
use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::ProjectManager ();
use DNALC::Pipeline::App::Utils ();
use DNALC::Pipeline::TargetProject ();


my $GBROWSE_TMP_ROOT = '/var/www/html/gbrowse/tmp';

$ENV{GMOD_ROOT} = '/usr/local/gmod';
my $cf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my ($y1, $m1, $d1) = Today();

my @users = DNALC::Pipeline::User->search_like(username => 'guest%');
for my $u (@users) {
	next if $u->username eq 'guest';
	next unless $u->created;
	my ($y2, $m2, $d2) = parse_datetime($u->created);
	my $dd = Delta_Days(($y2, $m2, $d2), ($y1, $m1, $d1));
	next if $dd < 1;
	print STDERR  $u, ' ', $u->username, '; dd=', $dd, $/;


	&remove_gbrowse_tmp_files($u->username);
	&remove_projects($u);
	&remove_target_projects($u);
	&remove_apollo_files($u);
	&drop_chadodb($u);

	$u->delete;
}

#----------------------------------------------------------------------

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
	for my $p (@projects) {
		my $pm = DNALC::Pipeline::App::ProjectManager->new($p);
		# gbrowse dir/files
		# gmod conf
		my $organism_str = join('_', split /\s+/, $p->organism) . '_' . $p->common_name;

		my $cutils = eval {
					DNALC::Pipeline::Chado::Utils->new(
						username => $u->username,
						organism_string => $organism_str,
						profile => $pm->chado_user_profile,
						gbrowse_template => $cf->{GBROWSE_TEMPLATE},
						gbrowse_confdir  => $cf->{GBROWSE_CONF_DIR},
					);
				};
		if ($@) {
			print STDERR  "Unable to process project $p: ", $@, $/;
		}
		else {
			my $gmod_conf_file = $cutils->gmod_conf_file($p->id);
			print STDERR  "p.$p ->", $gmod_conf_file, $/;

			my $gbrowse_file = $cutils->gbrowse_chado_conf($p->id);
			print STDERR  "p.$p =>", $gbrowse_file , $/;

			unlink $gmod_conf_file, $gbrowse_file;
		}

		# project dir
		my $dir = $pm->work_dir;
		print STDERR  "p.$p DIR => ", $dir, $/;
		DNALC::Pipeline::App::Utils->remove_dir($dir);
		print STDERR  "Project = $p", $/;
		$p->delete;

		print STDERR  "----", $/;
	}
}

sub remove_target_projects() {
	my $u = shift;

	my @projects = DNALC::Pipeline::TargetProject->search(user_id => $u->id);
	for my $p (@projects) {
		my $dir = $p->work_dir;
		print STDERR  "target rm.$p: dir => ", $p->work_dir, $/;
		print STDERR  "Target $p", $/;
		$p->delete;
		DNALC::Pipeline::App::Utils->remove_dir($dir);
	}
}

sub remove_apollo_files {
	my $u = shift;
	my $username = $u->username;
	my $apollo_dir = $cf->{APOLLO_USERCONF_DIR};
	my @files = grep {/$apollo_dir\/$username/} <$apollo_dir/*>;
	unlink @files if @files;
}

sub drop_chadodb {
	my $u = shift;

	my $dbname = $u->username;
	return unless $dbname =~ /^guest/;
	my $cutils = DNALC::Pipeline::Chado::Utils->new(
						profile => $cf->{GMOD_PROFILE},
						gbrowse_template => $cf->{GBROWSE_TEMPLATE},
						gbrowse_confdir  => $cf->{GBROWSE_CONF_DIR},
		);
	my $conn_str = '-h ' . $cutils->host
				. ' -p ' . $cutils->port
				. ' -U ' . $cutils->dbuser;
	my $out = `psql $conn_str -l | egrep -e "^ $dbname"`;
	if ($out) {
		print STDERR  "Should remove db [$dbname]\n";
		system("dropdb $conn_str -q $dbname") == 0 or do {
				print STDERR  "Unable to drop database [$dbname]: ", $!, $/;
			};
	}
}


sub remove_gbrowse_tmp_files {
	my ($username) = @_;

	my @tmp_dirs = grep {/\/${username}_db_\d+$/o} <$GBROWSE_TMP_ROOT/*>;
	for (@tmp_dirs) {	
		DNALC::Pipeline::App::Utils->remove_dir($_);
	}

}
