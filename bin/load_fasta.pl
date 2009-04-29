#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

load_fasta.pl - Loads a user provided DNA sequence into chado

=head1 SYNOPSIS

  % load_fasta.pl --username <name> --fastapath <path>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item fastapath
 
Path to the fasta file

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

my ($PROFILE, $FASTAPATH, $USERNAME, $HELP);

GetOptions(
  'username=s'         => \$USERNAME,
  'fastapath=s'        => \$FASTAPATH,
  'profile=s'          => \$PROFILE,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;
die unless $FASTAPATH;

$PROFILE         ||= 'default';

my %args = (
  'username'        => $USERNAME,
  'profile'         => $PROFILE,
  'fastapath'       => $FASTAPATH,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->load_fasta();

exit(0);
