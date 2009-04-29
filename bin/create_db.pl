#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib/perl';

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

The path to bzip2 compressed PostgreSQL dump file (default:/usr/local/gmod/src/chado_dump.bz2)

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

my ($PROFILE, $DUMPPATH, $USERNAME, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'dumppath=s'         => \$DUMPPATH,
  'profile=s'          => \$PROFILE,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;

$DUMPPATH        ||= '/usr/local/gmod/src/ontology_only_chado_dump.bz2';
$PROFILE         ||= 'default';

my %args = (
  'username'  => $USERNAME,
  'dumppath'  => $DUMPPATH,
  'profile'   => $PROFILE,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->create_db();

exit(0);
