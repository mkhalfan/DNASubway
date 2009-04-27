#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib/perl';

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

load_analysis_results.pl - Loads a user provided GFF into chado

=head1 SYNOPSIS

  % load_fasta.pl --username <name> --data_dir <path>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item data_dir
 
Path to the directory containing GFF3 files

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=back

=head1 DESCRIPTION

This script takes a user provided fasta file and creates a feature for it in the
feature table and adds the sequence to it.

=head1 AUTHOR

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($PROFILE, $DATADIR, $USERNAME, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'data_dir=s'         => \$DATADIR,
  'profile=s'          => \$PROFILE,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;
die unless $DATADIR;

$PROFILE         ||= 'default';

my %args = (
  'username'        => $USERNAME,
  'profile'         => $PROFILE,
  'data_dir'        => $DATADIR,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->load_database();
$utils->create_gbrowse_conf();

exit(0);
