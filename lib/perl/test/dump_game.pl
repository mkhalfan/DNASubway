#!/usr/bin/perl -w

use strict;

use DNALC::Pipeline::Chado::Utils ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::App::ProjectManager ();
use Data::Dumper; 

$ENV{'GMOD_ROOT'} = '/usr/local/gmod';

my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $apollo      = $config->{APOLLO_HEADLESS};
#my $hostname    = $config->{APOLLO_PROJECT_HOME};
my $write_dir	= $config->{APOLLO_WRITE_DIR};
my $web_path    = $config->{APOLLO_WEB_PATH};
my $vendor      = $config->{APOLLO_VENDOR};
my $apollo_desc = $config->{APOLLO_DESC};

my $pid = 473;
my $start = 1;
my $stop  = 10_000;
my $pmanager = DNALC::Pipeline::App::ProjectManager->new($pid);
unless ($pmanager->project) {
    die "no project_id--can't go on";
}

warn "common-name for pid = $pid = ", $pmanager->cleaned_common_name, $/;
my $cutil = DNALC::Pipeline::Chado::Utils->new;
$cutil->profile( $pmanager->chado_user_profile );
my $conf_file = $cutil->create_chado_adapter($config->{APOLLO_USERCONF_DIR});

my $req_region = $pmanager->cleaned_common_name . ":$start-$stop";
my $game_file  = $config->{APOLLO_WRITE_DIR} . "/$req_region.xml";
my $web_game_file = $config->{APOLLO_WEB_PATH} . "/$req_region.xml";
#my $game_file  = "/tmp/$req_region.xml";

#print STDERR  "Game file = ", $game_file, $/;
my $javacmd = "$apollo -H -w $game_file -o game -l $req_region -i chadoDB -C $conf_file > /dev/null";
print STDERR  $javacmd , $/;
print STDERR  "\n$web_game_file\n", $/;
my $rc = system($javacmd);
#print "exit code = ", $rc, $/;

print STDERR  "\n\n", $/;
$cutils->write_jnlp({
	jnpl		=> $config->{APOLLO_WRITE_DIR} . "/$req_region.jnlp",
	hostname	=> 'http://pipeline-dev.dnalc.org',
	game_file	=> $web_game_file,
	vendor		=> $config->{APOLLO_VENDOR},
	apollo_desc => $config->{APOLLO_DESC},
});

