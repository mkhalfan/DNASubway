#!/usr/bin/perl
use strict;
use warnings;

use DNALC::Pipeline::Chado::Utils ();
use DNALC::Pipeline::Config ();
use File::Path;
use Getopt::Long;
use Pod::Usage;

my ($PROFILE, $DATADIR, $USERNAME, $GBROWSETEMPLATE, $GBROWSECONFDIR, $PID);

$USERNAME = 'H9VV';
$PID = 60;

$PROFILE         ||= 'default';
$GBROWSECONFDIR  ||= '/etc/httpd/conf/gbrowse.conf';
$GBROWSETEMPLATE ||= 'gbrowse.template';


my %args = (
  'username'         => $USERNAME,
  'gbrowse_template' => $GBROWSETEMPLATE,
  'gbrowse_confdir'  => $GBROWSECONFDIR,
  'organism_string'  => 'Urtica_dioica_urzica',
);

my $utils  = DNALC::Pipeline::Chado::Utils->new(%args);

#$utils->load_database();
my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');
# my $gbrowse_db_dir = $config->{GBROWSE_DB_DIR} . '/' . $USERNAME . '/' . $PID;
# unless (-d $gbrowse_db_dir) {
# 	eval { mkpath($gbrowse_db_dir); };
# 	if ($@) {
# 		print STDERR  "Unable to create dir: $@", $/;
# 	}
# }
my $f = $utils->create_gbrowse_conf($PID, $config->{GBROWSE_DB_DIR});
print "CONF = ", $f, $/;

