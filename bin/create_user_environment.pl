#!/usr/bin/perl
use strict;
use warnings;

use Bio::GMOD::Config;
use Bio::GMOD::DB::Config;
use Getopt::Long;
use Cwd;
use File::Copy;
use Pod::Usage;

=head1 NAME

create_user_environment.pl - Do administrative tasks for setting up a new user

=head1 SYNOPSIS

  % create_user_environment.pl --username <name> --organism_string <string> --data_dir <path>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item dumppath

The path to the PostgreSQL dump file (default:/usr/local/gmod/src/chado_dump.bz2)

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=item organism_string

A string that has the genus, species and common name concatentated with underscores.
Example: Test_testus_test or Homo_sapiens_human.

=item data_dir

The path to the directory where the user's GFF files.

=item gbrowse_template

The name of the template for creating GBrowse conf files (default:gbrowse.template)

=item gbrowse_confdir

The path to the GBrowse configuration file (default:/etc/httpd/conf/gbrowse.conf)

=back

=head1 DESCRIPTION

This script accomplishes several tasks:
  Creates a user-specific Chado database
  Creates a GMOD conf file in $GMOD_ROOT/conf
  Loads the Chado database with the user's analysis results
  Creates a GBrowse conf file

Soon (possibly): creates user specific Apollo conf stuff

=head1 AUTHOR

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


my ($HELP,$USERNAME, $DUMPPATH, $DBPROF, $ORGSTRING,
    $DATADIR,$GBROWSE_TEMPLATE,$GBROWSE_CONFDIR);


GetOptions(
  'username=s'         => \$USERNAME,
  'dumppath=s'         => \$DUMPPATH, 
  'profile=s'          => \$DBPROF,
  'organism_string=s'  =>\$ORGSTRING,
  'data_dir=s'         => \$DATADIR,
  'gbrowse_template=s' => \$GBROWSE_TEMPLATE,
  'gbrowse_confdir=s'  =>  \$GBROWSE_CONFDIR,
) or pod2usage(-verbose => 1, -exitval => 1);


die unless $USERNAME;

my @org_info = split('_', $ORGSTRING);
die unless (scalar @org_info == 3);

die unless $DATADIR;

$DUMPPATH        ||= '/usr/local/gmod/src/chado_dump.bz2';
$DBPROF          ||= 'default';
$GBROWSE_CONFDIR ||= '/etc/httpd/conf/gbrowse.conf';
$GBROWSE_TEMPLATE||= 'gbrowse.template';

my $gmod_conf = Bio::GMOD::Config->new();
my $db_conf   = Bio::GMOD::DB::Config->new($gmod_conf, $DBPROF);

my $db_user = $db_conf->user;
my $db_host = $db_conf->host;
my $db_port = $db_conf->port;


#start set up work

create_db($db_user, $db_host, $db_port, $USERNAME, $DUMPPATH);

create_conf_file($USERNAME,$db_user, $db_host,$db_port,\@org_info,$gmod_conf);

load_database($USERNAME, $DATADIR);

create_gbrowse_conf($USERNAME, $org_info[2],$GBROWSE_CONFDIR,$GBROWSE_TEMPLATE);

exit(0);

sub create_db {
    my ($user,$host,$port,$uname,$dumppath) = @_;
    system("createdb -U $user -h $host -p $port $uname");
    system("bzip2 -dc $dumppath | psql -U $user -h $host -p $port $uname");
    return;
}

sub create_conf_file {
    my ($user, $dbuser, $host, $port, $org_info, $gmod_conf) = @_;

    my $orig_dir = getcwd;
    my $confdir = $gmod_conf->confdir;
    chdir $confdir;

    my $conffile = "$user.conf"; 
    copy('default.conf',$conffile);

    system("perl -pi -e 's/DBNAME=chado/DBNAME=$user/' $conffile");
    system("perl -pi -e 's/DBORGANISM=/DBORGANISM=$$org_info[2]/' $conffile"); 
   
    insert_organism($user,$dbuser,$host,$port,$org_info);

    chdir $orig_dir;
    return; 
}

sub insert_organism {
    my ($user, $dbuser, $host, $port, $org_info) = @_;

    my $genus_init = substr($$org_info[0],0,1);

    #wow--the org string better be scrubbed before it gets here! Or we may get
    #a visit from little Jonny Tables
    system(qq(psql -U $dbuser -h $host -p $port -c "INSERT INTO organism (abbreviation,genus,species,common_name) VALUES ('$genus_init.$$org_info[1]','$$org_info[0]','$$org_info[1]','$$org_info[2]')" $user));

    return;
}

sub load_database {
    my ($conffile, $datadir) = @_;
    my $orig_dir = getcwd;

    chdir $datadir;

    my @gff_files = glob('*.gff*');

    foreach my $file (@gff_files) {
        my $command = "gmod_bulk_load_gff3.pl -a --noexon --dbprof $conffile -g $file";
        warn "$command\n";
        system($command);
    }

    chdir $orig_dir;
    return;
}

sub create_gbrowse_conf {
    my ($user, $organism, $confdir,$template) = @_;
    my $orig_dir = getcwd;

    chdir $confdir;
    
    my $conffile = "$user.conf";
    copy($template, $conffile);

    system("perl -pi -e 's/USER/$user/' $conffile"); 
    system("perl -pi -e 's/ORGANISM/$organism/' $conffile");

    chdir $orig_dir;
    return;
}
