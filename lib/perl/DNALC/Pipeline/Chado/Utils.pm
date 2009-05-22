package DNALC::Pipeline::Chado::Utils;

use strict;
use warnings;

use Bio::GMOD::Config ();
use Bio::GMOD::DB::Config ();
use Cwd;
use File::Path;
use IO::File ();
use Data::Dumper;

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

    $self->username        ( $arg{username})         if $arg{username};
    $self->dumppath        ( $arg{dumppath})         if $arg{dumppath};
    $self->profile         ( $arg{profile})          if $arg{profile};
    $self->organism_string ( $arg{organism_string})  if $arg{organism_string};
    $self->data_dir        ( $arg{data_dir})         if $arg{data_dir};
    $self->gbrowse_template( $arg{gbrowse_template}) if $arg{gbrowse_template};
    $self->gbrowse_confdir ( $arg{gbrowse_confdir})  if $arg{gbrowse_confdir};
    $self->fastapath       ( $arg{fastapath})        if $arg{fastapath};


    return $self;
}

=head2 fastapath

=over

=item Usage

  $obj->fastapath()        #get existing value
  $obj->fastapath($newval) #set new value

=item Function

=item Returns

value of fastapath (a scalar)

=item Arguments

new value of fastapath (to set)

=back

=cut

sub fastapath {
    my $self = shift;
    my $fastapath = shift if defined(@_);
    return $self->{'fastapath'} = $fastapath if defined($fastapath);
    return $self->{'fastapath'};
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
	$gbrowse_confdir = undef if defined ($gbrowse_confdir) && !-d $gbrowse_confdir;

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

    if ($organism_string) {
        my @org_array = split /_/, $organism_string;
        die "Improperly formated organism_string" unless scalar @org_array ==3;

        $self->genus($org_array[0]);
        $self->species($org_array[1]);
        $self->common_name($org_array[2]);

        my $genus_init = substr($org_array[0],0,1);

        $self->abbreviation("$genus_init.$org_array[1]");
    }

    return $self->{'organism_string'} = $organism_string  if defined($organism_string );
    return $self->{'organism_string'};
}


=head2 genus

=over

=item Usage

  $obj->genus()        #get existing value
  $obj->genus($newval) #set new value

=item Function

=item Returns

value of genus (a scalar)

=item Arguments

new value of genus (to set)

=back

=cut

sub genus {
    my $self = shift;
    my $genus = shift if defined(@_);
    return $self->{'genus'} = $genus if defined($genus);
    return $self->{'genus'};
}


=head2 species

=over

=item Usage

  $obj->species()        #get existing value
  $obj->species($newval) #set new value

=item Function

=item Returns

value of species (a scalar)

=item Arguments

new value of species (to set)

=back

=cut

sub species {
    my $self = shift;
    my $species = shift if defined(@_);
    return $self->{'species'} = $species if defined($species);
    return $self->{'species'};
}


=head2 common_name

=over

=item Usage

  $obj->common_name()        #get existing value
  $obj->common_name($newval) #set new value

=item Function

=item Returns

value of common_name (a scalar)

=item Arguments

new value of common_name (to set)

=back

=cut

sub common_name {
    my $self = shift;
    my $common_name = shift if defined(@_);
    return $self->{'common_name'} = $common_name if defined($common_name);
    return $self->{'common_name'};
}

=head2 abbreviation

=over

=item Usage

  $obj->abbreviation()        #get existing value
  $obj->abbreviation($newval) #set new value

=item Function

=item Returns

value of abbreviation (a scalar)

=item Arguments

new value of abbreviation (to set)

=back

=cut

sub abbreviation {
    my $self = shift;
    my $abbreviation = shift if defined(@_);
    return $self->{'abbreviation'} = $abbreviation if defined($abbreviation);
    return $self->{'abbreviation'};
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
        my $db_conf   = Bio::GMOD::DB::Config->new($gmod_conf, $profile);

        my $confdir = $gmod_conf->confdir;
        my $db_user = $db_conf->user;
        my $db_pass = $db_conf->password;
        my $db_host = $db_conf->host;
        my $db_port = $db_conf->port;
		#my $dbh     = $db_conf->dbh;

        $self->confdir($confdir);
        $self->dbuser ($db_user);
        $self->dbpassword ($db_pass);
        $self->port   ($db_port);
        $self->host   ($db_host);
		#$self->dbh    ($dbh);
    }

    return $self->{'profile'} = $profile if defined($profile);
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

=head2 dbpassword

=over

=item Usage

  $obj->dbpassword()        #get existing value
  $obj->dbpassword($newval) #set new value

=item Function

=item Returns

value of dbpassword (a scalar)

=item Arguments

new value of dbpassword (to set)

=back

=cut

sub dbpassword {
    my ($self, $dbpassword) = @_;

    return $self->{dbpassword} = $dbpassword if defined($dbpassword);
    return $self->{dbpassword};
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

=head2 dbh

=over

=item Usage

  $obj->dbh()        # gets a DB connection bases on the already set profile

=item Function

=item Returns

value of db handler

=back

=cut

sub dbh {
    my $self = shift;
	#my $dbh = shift if defined(@_);
	#return $self->{'dbh'} = $dbh if defined($dbh);
	return $self->{dbh} if defined $self->{dbh} && $self->{dbh}->ping;

	return unless $self->profile();

    my $gmod_conf = Bio::GMOD::Config->new();
    my $db_conf = Bio::GMOD::DB::Config->new($gmod_conf, $self->profile);
	$self->{dbh} = $db_conf->dbh;
}

sub create_conf_file {
    my ($self, $project_id) = @_;

	unless ($project_id && $project_id =~ /\d+/) {
		warn "Project ID is missing or invalid\n";
		return;
	}

	unless ($self->profile) {
		warn "Profiles was not set!\n";
		return;
	}

	my $username = $self->username;
    my $confdir = $self->confdir;
	unless ($confdir && -w $confdir ) {
		warn "Config dir [$confdir] is not writable.\n\n";
	}

    my $conffile = sprintf("%s/%s_%d.conf", $confdir, $username, $project_id); 

    if (-f $conffile) {
        warn "Configuration file for this user [$username] already exists.";
    }
    else {
		my $in  = IO::File->new( $confdir . '/' . $self->profile . '.conf' );
		my $out = IO::File->new( "> $conffile" );
		if (defined $in && $out) {
			my $organism = $self->common_name;
			while (my $line = <$in> ) {
				$line =~ s/DBNAME=chado/DBNAME=$username/;
				$line =~ s/DBORGANISM=/DBORGANISM=$organism/;
				print $out $line;
			}
			undef $in;
			undef $out;
		}
		else {
			warn "Unable to create project conf file: ", $conffile , "\n";
		}
    }

    return $conffile if (-f $conffile);
}

sub create_db {
    my ($self, $quiet) = @_;
	
	my $q = $quiet ? '-q' : '';

	system("createdb $q"
			. " -U " . $self->dbuser 
			. " -h " . $self->host
			. " -p " . $self->port
	       . " ". $self->username
		) == 0 or (die "Database called ".$self->username." already exists\n");

    system("psql $q -U ".$self->dbuser
             . " -h ".$self->host
             . " -p ".$self->port
             . " ". $self->username 
			 . " < " . $self->dumppath
			 . ( $quiet ? ' > /dev/null 2>&1' : '')
		 ) == 0 or do {
				 warn "Unable to load data into new Chado DB [" 
					. $self->dbuser . "].\n";
				return;
			};

    return 1; # success
}


sub insert_organism {
    my $self = shift;

    my $dbh = $self->dbh;

    #check to see if the organism is already in the db
    my $query = "SELECT abbreviation,genus,species,common_name FROM organism WHERE common_name = ?
					OR (genus = ? AND species = ?)";
    my $sth   = $dbh->prepare($query);
    $sth->execute($self->common_name, $self->genus, $self->species) or die $dbh->errstr;
    my $hash_ref = $sth->fetchrow_hashref;
	$sth->finish;

    if ($$hash_ref{common_name}) {
        if ($$hash_ref{abbreviation} ne $self->abbreviation or
            $$hash_ref{genus}         ne $self->genus or
            $$hash_ref{species}       ne $self->species) {
            die $self->common_name." is already in the database but not with the given genus and species"; 
        }
        else {
            warn "nothing to do--this organism is already in the database\n";
            return;
        } 
    }

    #wow--the org string better be scrubbed before it gets here! Or we may get
    #a visit from little Jonny Tables
    #no really need for the overhead of DBI here for on query.
    my $insert_query= "INSERT INTO organism (abbreviation,genus,species,common_name) VALUES (?,?,?,?)";
    $sth  = $dbh->prepare($insert_query);
    $sth->execute($self->abbreviation,$self->genus,$self->species,$self->common_name) or die $dbh->errstr; 

	$dbh->disconnect;

    return;
}

sub load_database {
    my $self  = shift;

    my $orig_dir = getcwd;

    chdir $self->data_dir;

    my @gff_files = glob('*.gff*');

    my $user = $self->username;
    foreach my $file (@gff_files) {
        my $command = "gmod_bulk_load_gff3.pl -a --noexon --dbprof $user -g $file";
        warn "$command\n";
        system($command);
    }

    chdir $orig_dir;
    return;
}

sub create_gbrowse_conf {
    my ($self, $project_id, $base_db_dir) = @_;
	print STDERR Dumper( $self ), $/;
 
	unless ($project_id && $project_id =~ /\d+/) {
		warn "Project ID is missing or invalid\n";
		return;
	}

    my $username = $self->username; 
    my $organism = $self->common_name;
    my $confdir  = $self->gbrowse_confdir;

	if (defined $base_db_dir) {
		my $gbrowse_db_dir = $base_db_dir . '/' . $username . '/' . $project_id;
		unless (-d $gbrowse_db_dir) {
			print STDERR "Creating gBrowse DB dir: ", $gbrowse_db_dir, $/;
			eval { mkpath($gbrowse_db_dir); };
			if ($@) {
				print STDERR  "Unable to create gbrowse db dir: $@", $/;
			}
		}
		else {
			print STDERR  "BBrowse DB dir already exists: ", $gbrowse_db_dir, $/;;
		}
	}

	unless ($confdir && -w $confdir ) {
		warn "GBrowse config dir [$confdir] is not writable.\n\n";
		return;
	}

    my $conffile = sprintf("%s/%s_%d.conf", $confdir, $username, $project_id); 
	#return if -f $conffile;
	print STDERR  "Config dir = ", $confdir, $/;
	print STDERR  "Config file = ", $conffile, $/;
	if (-f $conffile) {
        warn "Gbrowse configuration file for this user [$username].[pid=$project_id] already exists.";
		return $conffile;
	}
	my $in  = IO::File->new( $confdir . '/' . $self->gbrowse_template );
	my $out = IO::File->new( "> $conffile" );
	if (defined $in && $out) {
		my $organism = $self->common_name;
		while (my $line = <$in> ) {
			$line =~ s/__USER__/$username/;
			$line =~ s/__ORGANISM__/$organism/;
			$line =~ s/__PID__/$project_id/;
			print $out $line;
		}
		undef $in;
		undef $out;
	}
	else {
		warn "Unable to create gbrowse conf file: ", $conffile , "\n";
	}
   
    return $conffile if (-f $conffile);
}

sub load_fasta {
    my $self = shift;


    my ($id, $seq);
    #parse fasta file
    open FASTA, $self->fastapath or die;
    while (<FASTA>) {
        chomp;
        if (/^>(\S+)/) {
            $id = $1;
            $seq= '';
        }
        else {
            $seq .= $_;
        }
    }        
    close FASTA;

    my $length = length $seq;

    #create GFF file
    my $fh = File::Temp->new(); #may need unlink=0 here
    my $filename = $fh->filename;
    print $fh join("\t",$id,$self->user,'contig',1,$length,'.','.','.',"ID=$id,Name=$id"),"\n";
    print $fh "###\n";
    print $fh "##FASTA\n";
    print $fh "$seq\n";
    close $fh;

    #load
    my $dbprof = $self->username;
    system("gmod_bulk_load_gff3.pl --dbprof $dbprof -g $filename") == 0 or die "fasta load failed";

    return;
}

1;
