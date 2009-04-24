package DNALC::Pipeline::Chado::Utils;

use strict;
use warnings;

use Bio::GMOD::Config;
use Bio::GMOD::DB::Config;
use Cwd;
use File::Copy;

=head1 NAME

DNALC::Pipeline::Chado::Utils - Do administrative tasks for setting up a new user

=head1 SYNOPSIS

  use DNALC::Pipeline::Chado::Utils;
  my $util = DNALC::Pipeline::Chado::Utils->new(%args};

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


sub new {
    my $class = shift;
    my %arg   = @_;

    my $self  = bless {}, ref($class) || $class;

    $self->username        ( $arg{username})         if $arg{username}
    $self->dumppath        ( $arg{dumppath})         if $arg{dumppath};
    $self->profile         ( $arg{profile})          if $arg{profile};
    $self->organism_string ( $arg{organism_string})  if $arg{organism_string};
    $self->data_dir        ( $arg{data_dir})         if $arg{data_dir};
    $self->gbrowse_template( $arg{gbrowse_template}) if $arg{gbrowse_template};
    $self->gbrowse_confdir ( $arg{gbrowse_confdir})  if $arg{gbrowse_confdir};



    return $self;
}

=head2 gbrowse_confdir 

=over

=item Usage

  $obj->gbrowse_confdir ()        #get existing value
  $obj->gbrowse_confdir ($newval) #set new value

=item Function

=item Returns

value of gbrowse_confdir  (a scalar)

=item Arguments

new value of gbrowse_confdir  (to set)

=back

=cut

sub gbrowse_confdir  {
    my $self = shift;
    my $gbrowse_confdir  = shift if defined(@_);
    return $self->{'gbrowse_confdir'} = $gbrowse_confdir  if defined($gbrowse_confdir );
    return $self->{'gbrowse_confdir'};
}

=head2 gbrowse_template

=over

=item Usage

  $obj->gbrowse_template()        #get existing value
  $obj->gbrowse_template($newval) #set new value

=item Function

=item Returns

value of gbrowse_template (a scalar)

=item Arguments

new value of gbrowse_template (to set)

=back

=cut

sub gbrowse_template {
    my $self = shift;
    my $gbrowse_template = shift if defined(@_);
    return $self->{'gbrowse_template'} = $gbrowse_template if defined($gbrowse_template);
    return $self->{'gbrowse_template'};
}

=head2 data_dir        

=over

=item Usage

  $obj->data_dir        ()        #get existing value
  $obj->data_dir        ($newval) #set new value

=item Function

=item Returns

value of data_dir         (a scalar)

=item Arguments

new value of data_dir         (to set)

=back

=cut

sub data_dir         {
    my $self = shift;
    my $data_dir         = shift if defined(@_);
    return $self->{'data_dir'} = $data_dir         if defined($data_dir        );
    return $self->{'data_dir'};
}

=head2 organism_string 

=over

=item Usage

  $obj->organism_string ()        #get existing value
  $obj->organism_string ($newval) #set new value

=item Function

=item Returns

value of organism_string  (a scalar)

=item Arguments

new value of organism_string  (to set)

=back

=cut

sub organism_string  {
    my $self = shift;
    my $organism_string  = shift if defined(@_);
    return $self->{'organism_string'} = $organism_string  if defined($organism_string );
    return $self->{'organism_string'};
}

=head2 profile         

=over

=item Usage

  $obj->profile         ()        #get existing value
  $obj->profile         ($newval) #set new value

=item Function

As a side effect of setting profile, confdir, dbuser, host and port are set.

=item Returns

value of profile          (a scalar)

=item Arguments

new value of profile          (to set)

=back

=cut

sub profile          {
    my $self = shift;
    my $profile          = shift if defined(@_);

    if ($profile) {
        #if profile is set, we'll want dbuser, host and port later
        my $gmod_conf = Bio::GMOD::Config->new();
        my $db_conf   = Bio::GMOD::DB::Config->new($gmod_conf, $DBPROF);

        my $confdir = $gmod_conf->confdir;
        my $db_user = $db_conf->user;
        my $db_host = $db_conf->host;
        my $db_port = $db_conf->port;

        $self->confdir($confdir);
        $self->dbuser ($db_user);
        $self->port   ($db_port);
        $self->host   ($db_host);
    }

    return $self->{'profile'} = $profile          if defined($profile         );
    return $self->{'profile'};
}

=head2 dumppath        

=over

=item Usage

  $obj->dumppath        ()        #get existing value
  $obj->dumppath        ($newval) #set new value

=item Function

=item Returns

value of dumppath         (a scalar)

=item Arguments

new value of dumppath         (to set)

=back

=cut

sub dumppath         {
    my $self = shift;
    my $dumppath         = shift if defined(@_);
    return $self->{'dumppath'} = $dumppath         if defined($dumppath        );
    return $self->{'dumppath'};
}

=head2 username        

=over

=item Usage

  $obj->username        ()        #get existing value
  $obj->username        ($newval) #set new value

=item Function

=item Returns

value of username         (a scalar)

=item Arguments

new value of username         (to set)

=back

=cut

sub username         {
    my $self = shift;
    my $username         = shift if defined(@_);
    return $self->{'username'} = $username         if defined($username        );
    return $self->{'username'};
}

=head2 host

=over

=item Usage

  $obj->host()        #get existing value
  $obj->host($newval) #set new value

=item Function

=item Returns

value of host (a scalar)

=item Arguments

new value of host (to set)

=back

=cut

sub host {
    my $self = shift;
    my $host = shift if defined(@_);
    return $self->{'host'} = $host if defined($host);
    return $self->{'host'};
}

=head2 port

=over

=item Usage

  $obj->port()        #get existing value
  $obj->port($newval) #set new value

=item Function

=item Returns

value of port (a scalar)

=item Arguments

new value of port (to set)

=back

=cut

sub port {
    my $self = shift;
    my $port = shift if defined(@_);
    return $self->{'port'} = $port if defined($port);
    return $self->{'port'};
}

=head2 dbuser

=over

=item Usage

  $obj->dbuser()        #get existing value
  $obj->dbuser($newval) #set new value

=item Function

=item Returns

value of dbuser (a scalar)

=item Arguments

new value of dbuser (to set)

=back

=cut

sub dbuser {
    my $self = shift;
    my $dbuser = shift if defined(@_);
    return $self->{'dbuser'} = $dbuser if defined($dbuser);
    return $self->{'dbuser'};
}

=head2 confdir

=over

=item Usage

  $obj->confdir()        #get existing value
  $obj->confdir($newval) #set new value

=item Function

=item Returns

value of confdir (a scalar)

=item Arguments

new value of confdir (to set)

=back

=cut

sub confdir {
    my $self = shift;
    my $confdir = shift if defined(@_);
    return $self->{'confdir'} = $confdir if defined($confdir);
    return $self->{'confdir'};
}


sub create_db {
    my $self = shift;

    system("createdb -U "
             .$self->dbuser." -h "
             .$self->host." -p "
             .$self->port
             ." ".$self->username) == 0 
                 or (warn "Database called ".$self->username." already exists\n" and die;);
    system("bzip2 -dc ".$self->dumppath
             ." | psql -U ."$self->dbuser
             ." -h ".$self->host
             ." -p ".$self->port
             ." ".$self->username);
    return;
}

sub create_conf_file {
    my $self = shift;

    my $orig_dir = getcwd;
    my $confdir = $self->confdir;
    chdir $confdir;

    my $conffile = "$user.conf"; 
    copy('default.conf',$conffile);

    system("perl -pi -e 's/DBNAME=chado/DBNAME=".$self->username."/' $conffile");
    system("perl -pi -e 's/DBORGANISM=/DBORGANISM=$$org_info[2]/' $conffile"); 
   
    insert_organism($user,$dbuser,$host,$port,$org_info);

    chdir $orig_dir;
    return; 
}

sub insert_organism {
    my $self = shift;

    my $genus_init = substr($$org_info[0],0,1);

    #wow--the org string better be scrubbed before it gets here! Or we may get
    #a visit from little Jonny Tables
    system(qq(psql -U $dbuser -h $host -p $port -c "INSERT INTO organism (abbreviation,genus,species,common_name) VALUES ('$genus_init.$$org_info[1]','$$org_info[0]','$$org_info[1]','$$org_info[2]')" $user));

    return;
}

sub load_database {
    my $self  = shift;

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
    my $self = shift;
 
    my $orig_dir = getcwd;

    chdir $confdir;
    
    my $conffile = "$user.conf";
    copy($template, $conffile);

    system("perl -pi -e 's/USER/$user/' $conffile"); 
    system("perl -pi -e 's/ORGANISM/$organism/' $conffile");

    chdir $orig_dir;
    return;
}
