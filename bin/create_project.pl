#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib/perl';

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

create_project.pl - creates GMOD conffile and preps Chado with organism info

=head1 SYNOPSIS

  % create_project.pl --username <name> --organism_string <string>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=item organism_string

A string that has the genus, species and common name concatentated with underscores.
Example: Test_testus_test or Homo_sapiens_human.

=back

=head1 DESCRIPTION

This script takes command line arguemnts and creates a GMOD configuration file
for the user and adds the organism to the database if needed.

=head1 AUTHOR

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($PROFILE, $ORGSTRING, $USERNAME, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'organism_string=s'  => \$ORGSTRING,
  'profile=s'          => \$PROFILE,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;
die unless $ORGSTRING;

$PROFILE         ||= 'default';

my %args = (
  'username'        => $USERNAME,
  'organism_string' => $ORGSTRING,
  'profile'         => $PROFILE,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->create_conf_file();

# read the data from the new profile
$utils->profile($USERNAME);

$utils->insert_organism();

exit(0);
