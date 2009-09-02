#!/usr/bin/perl 

use strict;
use warnings;

use File::Path qw/rmtree/;
use DNALC::Pipeline::App::ProjectManager ();

$ENV{GMOD_ROOT} = '/usr/local/gmod';
my $PID = 494;

my $pm = DNALC::Pipeline::App::ProjectManager->new($PID);
unless ($pm->project) {
	print STDERR  "Project already gone...", $/;
	exit 0;
}

# TODO check if there is any routine running..
print STDERR  'to rm: ', $pm->work_dir, $/;
my $workdir = $pm->work_dir;
if (-e $workdir) {
	rmtree $workdir, 1, 1;
}

my $cutils = DNALC::Pipeline::Chado::Utils->new(
				username => $pm->username,
				dumppath => $pm->config->{GMOD_DUMPFILE},
				profile => $pm->config->{GMOD_PROFILE},
				gbrowse_confdir  => $pm->config->{GBROWSE_CONF_DIR},
			);
my $conffile = $cutils->create_conf_file( $PID );
print STDERR  'to rm: ', $conffile, $/;
unlink $conffile;

my $gb_conf = $cutils->create_gbrowse_chado_conf( $PID );
print STDERR  'to rm: ', $gb_conf, $/;
unlink $gb_conf;

$pm->project->delete;

