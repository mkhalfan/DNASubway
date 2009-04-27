#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib/perl';

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

my ($PROFILE, $DUMPPATH, $USERNAME, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'dumppath=s'         => \$DUMPPATH,
  'profile=s'          => \$PROFILE,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;

$DUMPPATH        ||= '/usr/local/gmod/src/chado_dump.bz2';
$PROFILE         ||= 'default';

my %args = (
  'username'  => $USERNAME,
  'dumppath'  => $DUMPPATH,
  'profile'   => $PROFILE,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->create_db();

exit(0);
