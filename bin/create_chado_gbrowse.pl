#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib/perl';

use DNALC::Pipeline::Chado::Utils;
use Getopt::Long;
use Pod::Usage;

=head1 NAME

create_chado_gbrowse.pl - Create a GBrowse configuation file for a chado database

=head1 SYNOPSIS

  % create_chado_gbrowse.pl --username <name> --organism <org string> --gbrowse_confdir <path> --chado_gbrowse <path>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item project_id

Project ID number

=item chado_gbrowse

Path to the Chado GBrowse conf template file (default:gbrowse_chado.template)

=item gbrowse_confdir

The path to the GBrowse configuration file (default:/etc/httpd/conf/gbrowse.conf)

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=back

=head1 DESCRIPTION


=head1 AUTHOR

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($PROFILE, $ORGANISM, $USERNAME, $GBROWSETEMPLATE, $GBROWSECONFDIR, $HELP, $PROJECTID);

GetOptions(
  'username=s'         => \$USERNAME,
  'organism=s'         => \$ORGANISM,
  'gbrowse_chado=s'    => \$GBROWSETEMPLATE,
  'gbrowse_confdir=s'  => \$GBROWSECONFDIR,
  'profile=s'          => \$PROFILE,
  'project_id=s'       => \$PROJECTID,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

die unless $USERNAME;
die unless $ORGANISM;
die unless $PROJECTID;

$PROFILE         ||= 'default';
$GBROWSECONFDIR  ||= '/etc/httpd/conf/gbrowse.conf';
$GBROWSETEMPLATE ||= 'gbrowse_chado.template';


my %args = (
  'username'        => $USERNAME,
  'profile'         => $PROFILE,
  'organism_string' => $ORGANISM,
  'chado_gbrowse'   => $GBROWSETEMPLATE,
  'gbrowse_confdir' => $GBROWSECONFDIR,
  'project_id'      => $PROJECTID,
);

my $utils = DNALC::Pipeline::Chado::Utils->new(%args);

$utils->create_gbrowse_chado_conf($PROJECTID);

exit(0);
