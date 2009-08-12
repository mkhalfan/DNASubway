#!/usr/bin/perl -w

use strict;

use DNALC::Pipeline::Chado::Utils ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::App::ProjectManager ();
use Data::Dumper; 

$ENV{'GMOD_ROOT'} = '/usr/local/gmod';

my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $working_dir = $config->{APOLLO_WRITE_DIR};
my $apollo      = $config->{APOLLO_HEADLESS};
my $hostname    = $config->{APOLLO_PROJECT_HOME};
my $web_path    = $config->{APOLLO_WEB_PATH};
my $vendor      = $config->{APOLLO_VENDOR};
my $apollo_desc = $config->{APOLLO_DESC};

my $pid = 473;
my $pmanager = DNALC::Pipeline::App::ProjectManager->new($pid);
unless ($pmanager->project) {
    die "no project_id--can't go on";
}

warn "common-name for pid = $pid = ", $pmanager->cleaned_common_name, $/;
my $cutil = DNALC::Pipeline::Chado::Utils->new;
$cutil->profile( $pmanager->chado_user_profile );
my $conf_file = $cutil->create_chado_adapter($config->{APOLLO_USERCONF_DIR});

print STDERR  "Conf file = ", $conf_file, $/;


