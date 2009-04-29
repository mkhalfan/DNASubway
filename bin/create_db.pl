#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

create_db.pl - set up a new user's database

=head1 SYNOPSIS

  % create_db.pl --username <name>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item dumppath

The path to PostgreSQL dump file (default: /usr/local/gmod/src/ontology_only_chado_dump.sql)

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=back

=head1 DESCRIPTION

This script takes command line arguemnts and creates a chado database
poplulated with ontology terms but no features.

=head1 AUTHOR

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($PROFILE, $DUMPPATH, $USERNAME, $QUIET, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'dumppath=s'         => \$DUMPPATH,
  'profile=s'          => \$PROFILE,
  'quiet'              => \$QUIET,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;

$DUMPPATH        ||= '/usr/local/gmod/src/ontology_only_chado_dump.sql';
$PROFILE         ||= 'default';

my %args = (
  'username'  => $USERNAME,
  'dumppath'  => $DUMPPATH,
  'profile'   => $PROFILE,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->create_db($QUIET);


exit(0);
