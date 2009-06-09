#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use DNALC::Pipeline::Chado::Utils ();
use Getopt::Long;
use Pod::Usage;

=head1 NAME

load_analysis_results.pl - Loads a user provided GFF into chado

=head1 SYNOPSIS

  % load_fasta.pl --username <name> --profile <profile> --algorithm <algorithm> --gff <path>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item data_dir
 
Path to the directory containing GFF3 files

=item project_id

Project ID number

=item gbrowse_template

The name of the template for creating GBrowse conf files (default:gbrowse.template)

=item gbrowse_confdir

The path to the GBrowse configuration file (default:/etc/httpd/conf/gbrowse.conf)

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

my ($PROFILE, $FILE, $USERNAME, $HELP, $ALG);

GetOptions(
  'username=s'         => \$USERNAME,
  'gff=s'              => \$FILE,
  'profile=s'          => \$PROFILE,
  'algorithm=s'        => \$ALG,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die "Username is mising.\n" unless $USERNAME;
die "GFF file is mising.\n" unless $FILE;

$PROFILE         ||= 'default';

my %args = (
  'username'        => $USERNAME,
  'profile'         => $PROFILE,
);

$ENV{GMOD_ROOT} = '/usr/local/gmod';

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->load_analysis_results($FILE, $ALG);

exit(0);
