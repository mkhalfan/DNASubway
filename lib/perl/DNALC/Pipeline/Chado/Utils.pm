package DNALC::Pipeline::Chado::Utils;

use strict;
use warnings;

use Bio::GMOD::Config ();
use Bio::GMOD::DB::Config ();
use Bio::DB::Das::Chado ();
use File::Temp ();
use File::Path;
use IO::File ();
use Data::Dumper;

{
no Apache::DBI;

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
  Creates user specific Apollo conf stuff

=head1 AUTHORS

Scott Cain E<lt>cain.cshl@gmail.orgE<gt>
Cornel Ghiban E<lt>ghiban@@cshl.eduE<gt>

Copyright (c) 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my %algorithm_params = (
    AUGUSTUS            => '-a --noexon',
    BLASTN              => '-a',
    BLASTN_USER         => '-a',
    BLASTX              => '-a',
    BLASTX_USER         => '-a',
    FGENESH             => '-a --noexon',
    REPEAT_MASKER       => '-a',
    REPEAT_MASKER2      => '-a',
    SNAP                => '-a --noexon',
    TRNA_SCAN           => '-a',
);


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
	#$self->fastapath       ( $arg{fastapath})        if $arg{fastapath};
    $self->project_id      ( $arg{project_id})       if $arg{project_id};
    $self->chado_gbrowse   ( $arg{chado_gbrowse})    if $arg{chado_gbrowse};


    return $self;
}

=head2 chado_gbrowse

=over

=item Usage

  $obj->chado_gbrowse()        #get existing value
  $obj->chado_gbrowse($newval) #set new value

=item Function

Sets the path of the Chado-specific GBrowse conf file template.

=item Returns

value of chado_gbrowse (a scalar)

=item Arguments

new value of chado_gbrowse (to set)

=back

=cut

sub chado_gbrowse {
    my $self = shift;
    my $chado_gbrowse = shift if defined(@_);
    return $self->{'chado_gbrowse'} = $chado_gbrowse if defined($chado_gbrowse);
    return $self->{'chado_gbrowse'};
}


=head2 project_id

=over

=item Usage

  $obj->project_id()        #get existing value
  $obj->project_id($newval) #set new value

=item Function

=item Returns

value of project_id (a scalar)

=item Arguments

new value of project_id (to set)

=back

=cut

sub project_id {
    my $self = shift;
    my $project_id = shift if defined(@_);
    return $self->{'project_id'} = $project_id if defined($project_id);
    return $self->{'project_id'};
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
        my $db_conf   = eval {Bio::GMOD::DB::Config->new($gmod_conf, $profile);};
		if ($@) {
			return;
		}

        my $confdir = $gmod_conf->confdir;
        my $db_user = $db_conf->user;
        my $db_pass = $db_conf->password;
        my $db_host = $db_conf->host;
        my $db_port = $db_conf->port;

        $self->confdir($confdir);
		$self->dbname ( $db_conf->name );
        $self->dbuser ($db_user);
        $self->dbpassword ($db_pass);
        $self->port ($db_port);
        $self->host ($db_host);

		# we've changed the profile, so the connection is changing also..
		delete $self->{dbh} if defined $self->{dbh};
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


=head2 dbname

=cut 

sub dbname {
    my $self = shift;
    my $dbname = shift if defined(@_);
    return $self->{'dbname'} = $dbname if defined($dbname);
    return $self->{'dbname'};
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
	return $self->{dbh} if defined $self->{dbh} && $self->{dbh}->ping;

	return unless $self->profile();

    my $gmod_conf = Bio::GMOD::Config->new();
    my $db_conf = Bio::GMOD::DB::Config->new($gmod_conf, $self->profile);
	$self->{dbh} = $db_conf->dbh;
}

sub gmod_conf_file {
    my ($self, $project_id, $dbname_override) = @_;

	unless ($project_id && $project_id =~ /\d+/) {
		warn "Project ID is missing or invalid\n";
		return;
	}

	unless ($self->profile) {
		warn "Profile was not specified!\n";
		return;
	}

	my $username = $self->username;
	my $dbname  = $username;
    my $confdir = $self->confdir;
	unless ($confdir && -w $confdir ) {
		warn "Config dir [$confdir] is not writable.\n\n";
	}

    my $conffile = sprintf("%s/%s_%d.conf", $confdir, $username, $project_id); 

    if (-f $conffile) {
		#warn "Configuration file for this user [$username] already exists.";
    }
    else {
		if ($dbname_override) {
			$dbname = $dbname_override;
		}
		my $in  = IO::File->new( $confdir . '/' . $self->profile . '.conf' );
		my $out = IO::File->new( "> $conffile" );
		if (defined $in && $out) {
			my $organism = $self->common_name;
			while (my $line = <$in> ) {
				$line =~ s/DBNAME=chado/DBNAME=$dbname/;
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

sub get_pool_size {
	my ($self) = @_;

	my $dbh = $self->dbh;
	unless ($dbh) {
		print STDERR "Unable to connect to DB\n";
		return;
	}

	my $query = "SELECT count(*) FROM pg_database WHERE datname like 'pool_%'";

	my $sth   = $dbh->prepare($query);
	$sth->execute or die $dbh->errstr;
	my ($db_num) = $sth->fetchrow_array;
	$sth->finish;

	return $db_num;
}

sub assign_pool_db {
	my ($self, $username) = @_;
	my $dbh = $self->dbh;
	unless ($dbh) {
		print STDERR "Unable to connect to DB\n";
		return;
	}

	#my $query = "SELECT datname FROM pg_database WHERE datname like 'pool_%'";
	my $query = "SELECT datname FROM pg_database WHERE datname LIKE 'pool_%' ORDER BY RANDOM() LIMIT 1";

	my $sth   = $dbh->prepare($query);
	$sth->execute or die $dbh->errstr;
	my ($db_name) = $sth->fetchrow_array;
	$sth->finish;

	return unless $db_name;

	my $rc = undef;
	eval {
		print STDERR  "ALTER DATABASE $db_name RENAME TO $username", $/;
		$rc = $dbh->do("ALTER DATABASE $db_name RENAME TO $username");
	};
	if ($@)  {
		print STDERR  "assign_pool_db: ", $@, $/;
	}

	return $rc;
}

sub check_db_exists {
	my ($self, $db_name) = @_;

	my $dbh = $self->dbh;
	unless ($dbh) {
		print STDERR "Unable to connect to DB\n";
		return;
	}

	my $query = "SELECT count(*) FROM pg_database WHERE datname = ?";

	my $sth   = $dbh->prepare($query);
	$sth->execute($db_name) or die $dbh->errstr;
	my ($has_db) = $sth->fetchrow_array;
	$sth->finish;

	return $has_db;
}

sub create_db {
    my ($self, $quiet) = @_;

	#if ($self->check_db_exists( $self->username )) {
	#	return 1;
	#}
	
	my $q = $quiet ? '-q' : '';

	system("createdb $q"
			. " -U " . $self->dbuser 
			. " -h " . $self->host
			. " -p " . $self->port
	       . " ". $self->username
		) == 0 or do {
				print STDERR "create_db: Error: Perhaps we already have a db called [", $self->username, "]\n";
				return;
			};

    system("psql $q -U ".$self->dbuser
             . " -h ".$self->host
             . " -p ".$self->port
             . " ". $self->username 
			 . " < " . $self->dumppath
			 . ( $quiet ? ' > /dev/null 2>&1' : '')
		 ) == 0 or do {
				 print STDERR "Unable to load data into new Chado DB [", $self->dbuser, "].\n";
				return;
			};

    my $vacuum_cmd = "vacuumdb $q -U ".$self->dbuser
             . " -h " . $self->host
             . " -p " . $self->port
             . " -f -z "
             . " ". $self->username 
             . ( $quiet ? ' > /dev/null 2>&1' : '');
    #print STDERR $vacuum_cmd, $/;
    system( $vacuum_cmd ) == 0 or do {
				print STDERR "Unable to VACUUM Chado DB [", $self->username, "].\n";
				return;
			};

    return 1; # success
}


# tries to add the organism in the chado db.
# returns 1 on success
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
			#die $self->common_name." is already in the database but not with the given genus and species"; 
			print STDERR  "Organism ", $self->common_name, " is already in the BD but not with the given ",
						"genus and species.", $/;
			return;
        }
        else {
			#warn "nothing to do--this organism is already in the database\n";
            return 1;
        } 
    }

    #wow--the org string better be scrubbed before it gets here! Or we may get
    #a visit from little Jonny Tables
    #no really need for the overhead of DBI here for on query.
    my $insert_query= "INSERT INTO organism (abbreviation,genus,species,common_name) VALUES (?,?,?,?)";
    $sth  = $dbh->prepare($insert_query);
    $sth->execute($self->abbreviation,$self->genus,$self->species,$self->common_name) or do {
			print STDERR "Error inserting organism: ", $dbh->errstr, "\n";
			return;
		};

	$dbh->disconnect;

    return 1;
}

sub load_analysis_results {
    my ($self, $file, $alg) = @_;

	return unless -f $file;

	my $param = $self->additional_load_parameters(uc $alg);

	my $profile = $self->profile;
	my $command = "/usr/local/bin/gmod_bulk_load_gff3.pl $param --dbprof $profile -g $file";
	print STDERR "command = $command\n";
	print STDERR  "--------------------------------------------------", $/;
    my $rc = system($command);

	if ($? == -1) {
		print STDERR "failed to execute: $!\n";
	}
	elsif ($? & 127) {
		print STDERR  "child died with signal %d, %s coredump\n",
					($? & 127),  ($? & 128) ? 'with' : 'without', $/;
	} else {
		printf STDERR "child exited with value %d ~~ %d\n", $?, $? >> 8;
	}
	#print STDERR "rc = $rc ~ ", $? & 127, " ~ ", $? & 128 , "\n";
	#print STDERR  "--------------------------------------------------", $/;

    return $rc;
}

sub create_gbrowse_conf {
    my ($self, $project_id, $base_db_dir) = @_;
	#print STDERR Dumper( $self ), $/;
 
	unless ($project_id && $project_id =~ /\d+/) {
		warn "Project ID is missing or invalid\n";
		return;
	}

    my $username = $self->username; 
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

	return $conffile if -f $conffile;

    my $organism = $self->common_name;
	my $in  = IO::File->new( $confdir . '/' . $self->gbrowse_template );
	my $out = IO::File->new( "> $conffile" );
	if (defined $in && $out) {
		$organism =~ s/\s+/_/g;
		$organism =~ s/-/_/g;
		$organism .= '_' . $project_id;
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

sub gbrowse_chado_conf {
    my ( $self, $project_id, $dbname_override ) = @_;

    unless ($project_id && $project_id =~ /\d+/) {
        warn "Project ID is missing or invalid\n";
        return;
    }

    my $username = $self->username;
    my $organism = $self->common_name;
    my $confdir  = $self->gbrowse_confdir;

    unless ($confdir && -w $confdir ) {
        warn "GBrowse config dir [$confdir] is not writable.\n\n";
        return;
    }

    my $conffile = sprintf("%s/%s_db_%d.conf", $confdir, $username, $project_id);

    return $conffile if -f $conffile;

    my $in  = IO::File->new( $confdir . '/' . $self->chado_gbrowse );
    my $out = IO::File->new( "> $conffile" );
    if (defined $in && $out) {

		my $trimmed_organism = $organism;
		$trimmed_organism =~ s/\s+/_/g;
		$trimmed_organism =~ s/-/_/g;

		my $dbname = $username;
		if ($dbname_override) {
			$dbname = $dbname_override;
		}
        while (my $line = <$in> ) {
            $line =~ s/__USER__/$username/;
            $line =~ s/__ORGANISM__/$organism/;
            $line =~ s/__TRIMMED_ORGANISM__/$trimmed_organism/;
            $line =~ s/__PID__/$project_id/;
            $line =~ s/__DBNAME__/$dbname/;
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
    my ($self, $fastafile) = @_;

	return unless -f $fastafile;

    my ($id, $seq);
    #parse fasta file
    open FASTA, $fastafile or die;
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
	print $fh "$id\tDNALC\tchromosome\t1\t$length\t.\t.\t.\tID=$id;Name=$id\n";
#	print $fh join("\t", $id, $self->username, 'contig', 1, 
#			$length, '.', '.', '.', "ID=$id,Name=$id"),"\n";
    print $fh "###\n";
    print $fh "##FASTA\n";
    print $fh ">$id\n";
    print $fh "$seq\n";
    close $fh;

    #load
    my $dbprof = $self->profile;
    my $rc = system("/usr/local/bin/gmod_bulk_load_gff3.pl --dbprof $dbprof -g $filename");
	unless ($rc == 0) {
		# try again if we have a lock.
		if ($rc >> 8 == 254) {
			print STDERR  "*** waiting...5 secs: rc = ", $rc, '==', $rc >> 8, $/;
			sleep(5);
			$rc = system("/usr/local/bin/gmod_bulk_load_gff3.pl --dbprof $dbprof -g $filename");
		}
	}

    return $rc == 0;
}

sub additional_load_parameters {
    my $self = shift;
    my $alg  = shift;

    if (defined $algorithm_params{$alg}) {
        return $algorithm_params{$alg};
    }

    print STDERR "$alg isn't defined; the data load may not go as planned\n";
    return '';
}


# sets the ranks for any duplicate transcripts to 0
#
sub  fix_apollo_transcripts {
	my ($self, $trimmed_common_name) = @_;

	my $dbh = $self->dbh;

	#check to see if the organism is already in the db
	my $query = q{UPDATE featureloc SET rank=0 
			FROM feature
			WHERE feature.name = ? AND featureloc.rank > 0 AND featureloc.srcfeature_id = feature.feature_id};
	print STDERR "\n-----------------\n$query\n", $trimmed_common_name, "\n--------------\n";
	my $sth = $dbh->prepare($query);
	$sth->execute($trimmed_common_name) or do {
		print STDERR  "Unable to fix_apollo_transcripts: ", $!, $/;
	};
	$sth->finish;
	$dbh->disconnect;
}


sub create_chado_adapter {
    my ($self, $apollo_conf_dir) = @_;
	#my $project_id= shift;

	unless ($self->profile) {
		print STDERR  'Profile not loaded...', $/;
		return;
	}

	unless (-d $apollo_conf_dir) {
		print STDERR  'APOLLO USER CONF dir is missing...', $/;
		return;
	}

	my $profile	= $self->profile;

    my $dbname	= $self->dbname;
    my $dbuser	= $self->dbuser;
    my $dbhost	= $self->host;
    my $dbport  = $self->port;
	
	my $apollo_conf = $apollo_conf_dir . '/' . $dbname . '.conf';

	if (-f $apollo_conf) {
		return $apollo_conf;
	}
	#print STDERR  "**: apollo_conf: ", $apollo_conf, $/;
	#print STDERR  "**: profile: ", $profile, $/;
	my $apollo_chado_adapter = $apollo_conf_dir . '/' . $dbname . '.xml';
	
    #create chado-adapter.xml
	my $fh = new IO::File "> $apollo_chado_adapter";
	if (defined $fh) {
		print $fh <<END;
<?xml version="1.0" encoding="UTF-8"?>
<chado-adapter>
	<chadoInstance id="referenceInstance" default="true">
		<writebackXmlTemplateFile>transactionXMLTemplate.xml</writebackXmlTemplateFile>
		<featureCV>sequence</featureCV>
		<polypeptideType>polypeptide</polypeptideType>
		<relationshipCV>relationship</relationshipCV>
		<propertyTypeCV>feature_property</propertyTypeCV>
		<!-- default is part_of -->
		<partOfCvTerm>part_of</partOfCvTerm>
		<transProtRelationTerm>derives_from</transProtRelationTerm>
		<searchHitsHaveFeatLocs>true</searchHitsHaveFeatLocs>
		<clsName>apollo.dataadapter.chado.jdbc.FlybaseChadoInstance</clsName>

		<oneLevelAnnotTypes>
			<type>promoter</type>
			<type>insertion_site</type>
			<type>transposable_element</type>
			<type>transposable_element_insertion_site</type>
			<type>remark</type>
			<type>repeat_region</type>
		</oneLevelAnnotTypes>

		<threeLevelAnnotTypes>
			<type>gene</type>
			<type>pseudogene</type>
			<type>tRNA</type>
			<type>snRNA</type>
			<type>snoRNA</type>
			<type>ncRNA</type>
			<type>rRNA</type>
			<type>miRNA</type>
		</threeLevelAnnotTypes>

	</chadoInstance>

	<chadoInstance id="riceInstance" default="true">

		<inheritsInstance>referenceInstance</inheritsInstance>

		<partOfCvTerm>part_of</partOfCvTerm>
		<inheritsInstance>referenceInstance</inheritsInstance>
		<featureCV>sequence</featureCV>
		<relationshipCV>relationship</relationshipCV>
		<propertyTypeCV>feature_property</propertyTypeCV>
		<writebackXmlTemplateFile>transactionXMLTemplate_rice.xml</writebackXmlTemplateFile>
		<sequenceTypes>
			<type>gene</type>
			<type>
				<name>chromosome</name>
				<useStartAndEnd>true</useStartAndEnd>
				<queryForValueList>true</queryForValueList>
				<isTopLevel>true</isTopLevel>
			</type>
		</sequenceTypes>

	   <genePredictionPrograms>
			<program>FGenesH</program>
			<program>AUGUSTUS</program>
			<program>SNAP</program>
			<program>tRNAScan-SE</program>
		</genePredictionPrograms>

		<oneLevelResultPrograms>
			<program>RepeatMasker</program>
		</oneLevelResultPrograms>

		<searchHitPrograms>
			<program>BLASTN</program>
			<program>BLASTN_USER</program>
			<program>BLASTX</program>
			<program>BLASTX_USER</program>
		</searchHitPrograms>

		<searchHitsHaveFeatLocs>true</searchHitsHaveFeatLocs>

		<clsName>apollo.dataadapter.chado.jdbc.RiceChadoInstance</clsName>
	</chadoInstance>

    <chadoInstance id="ricePure">
       <inheritsInstance>riceInstance</inheritsInstance>
       <pureJDBCWriteMode>true</pureJDBCWriteMode>
       <pureJDBCCopyOnWrite>false</pureJDBCCopyOnWrite>
       <pureJDBCNoCommit>false</pureJDBCNoCommit>
       <!-- logDirectory>/Users/mgibson/.apollo</logDirectory -->
       <queryFeatureIdWithUniquename>true</queryFeatureIdWithUniquename>
       <queryFeatureIdWithName>true</queryFeatureIdWithName>
    </chadoInstance>

	<chadodb>
		<name>$profile</name>
		<adapter>apollo.dataadapter.chado.jdbc.PostgresChadoAdapter</adapter>
		<url>jdbc:postgresql://$dbhost:$dbport/$dbname</url>
		<dbName>$dbname</dbName>
		<dbUser>$dbuser</dbUser>
		<dbInstance>ricePure</dbInstance>
		<!--<style>dnalc.style</style>-->
		<default-command-line-db>true</default-command-line-db>
	</chadodb>
</chado-adapter>

END
		$fh->close;
	}
	else {
		print STDERR  "Chado::Utils::create_chado_adapter: unable to create the db adaptor..", $/;
	}

	if (-f $apollo_chado_adapter) {
		my $fh = new IO::File "> $apollo_conf";
		if (defined $fh) {
			#print $fh "NameAdapterInstall \"apollo.config.DefaultNameAdapter\"\n";
			print $fh "ChadoJdbcAdapterConfigFile \"$apollo_chado_adapter\"\n";
			$fh->close;
			return $apollo_conf;
		}
	}

    return;
}

sub remove_lock_file {
	print STDERR  "Not removing the chado adapter.xml", $/;
	return;
    unlink "/var/www/.apollo/chado-adapter.xml";
    return;
}

sub write_jnlp {

	my ($self, $args) = @_;
	my $jnlp = $args->{jnlp};
	my $web_jnlp = $args->{web_jnlp};
	my $hostname = $args->{hostname};
	my $game_file = $args->{game_file};
	my $vendor = $args->{vendor};
	my $apollo_desc = $args->{apollo_desc};
	my $pid	= $args->{pid};

	my $cdn = $args->{cdn} || '';

	#return <<END;
	my $fh = new IO::File "> $jnlp";
	if (defined $fh) {
		print $fh <<END;
<?xml version="1.0" encoding="UTF-8"?>
<jnlp codebase="$hostname/files/apollo/webstart/" spec="1.0+">
  <information>
    <title>Apollo</title>
    <vendor>$vendor</vendor>
    <description>$apollo_desc</description>
    <homepage href="$hostname/" />
    <icon href="/images/head-of-apollo.jpg" kind="shortcut"/>
    <offline-allowed/>
  </information>
  <security>
    <all-permissions/>
  </security>
  <resources>
    <j2se initial-heap-size="64m" max-heap-size="500m" version="1.6+"/>
    <jar href="${cdn}apollo-jars/apollo.jar"/>
    <jar href="${cdn}apollo-jars/bbop.jar"/>
    <jar href="${cdn}apollo-jars/biojava.jar"/>
    <jar href="${cdn}apollo-jars/crimson.jar"/>
    <jar href="${cdn}apollo-jars/ecp1_0beta.jar"/>
    <jar href="${cdn}apollo-jars/ensj-compatibility-19.0.jar"/>
    <jar href="${cdn}apollo-jars/ensj.jar"/>
    <jar href="${cdn}apollo-jars/jakarta-oro-2.0.6.jar"/>
    <jar href="${cdn}apollo-jars/jaxp.jar"/>
    <jar href="${cdn}apollo-jars/jnlp.jar"/>
    <jar href="${cdn}apollo-jars/junit.jar"/>
    <jar href="${cdn}apollo-jars/log4j-1.2.14.jar"/>
    <jar href="${cdn}apollo-jars/macify-1.1.jar"/>
    <jar href="${cdn}apollo-jars/mysql-connector-java-3.1.8-bin.jar"/>
    <jar href="${cdn}apollo-jars/obo.jar"/>
    <jar href="${cdn}apollo-jars/oboedit.jar"/>
    <jar href="${cdn}apollo-jars/org.mortbay.jetty.jar"/>
    <jar href="${cdn}apollo-jars/patbinfree153.jar"/>
    <jar href="${cdn}apollo-jars/pg74.213.jdbc3.jar"/>
    <jar href="${cdn}apollo-jars/psgr2.jar"/>
    <jar href="${cdn}apollo-jars/servlet-tomcat.jar"/>
    <jar href="${cdn}apollo-jars/te-common.jar"/>
    <jar href="${cdn}apollo-jars/xerces.jar"/>
  </resources>
  <application-desc main-class="apollo.main.Apollo">
    <argument>-i</argument>
    <argument>game</argument>
    <argument>-f</argument>
    <argument>$hostname$game_file</argument>
	<argument>-N</argument>
	<argument>$pid</argument>
  </application-desc>
</jnlp>
END
;
	}
}

}
1;
