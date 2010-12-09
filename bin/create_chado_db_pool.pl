#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Chado::Utils ();
use Getopt::Long;
use Pod::Usage;

use Data::Dumper; 

=head1 NAME

create_db.pl - set up a new user's database

=head1 SYNOPSIS

  % create_db.pl --username <name>

=head1 COMMAND-LINE OPTIONS

=over

=item username

The name of the web-based user

=item dumppath

The path to PostgreSQL dump file (default: /usr/local/gmod/src/ontology_only_chado_dump.sql)

=item profile

The name of the GMOD conf file to use for database connection info (default:default)

=back

=head1 DESCRIPTION

This script takes command line arguemnts and creates a chado database
poplulated with ontology terms but no features.

=head1 AUTHOR

Cornel Ghiban E<lt>ghiban@cshl.eduE<gt>

Copyright (c) 2010

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($QUIET, $HELP);

GetOptions(
  'quiet'              => \$QUIET,
  'help'               => \$HELP,
) or  pod2usage(-verbose => 1, -exitval => 1);

pod2usage(-verbose => 2, -exitval => 1) if $HELP;

my $conf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my %args = (
	'dumppath'  => $conf->{GMOD_DUMPFILE},
	'profile'   => $conf->{GMOD_PROFILE},
);

my $tries = 5;
$ENV{GMOD_ROOT} ||= $conf->{GMOD_ROOT};

my $cutils = DNALC::Pipeline::Chado::Utils->new(%args);


my $pool_size = $cutils->get_pool_size;
#print "pool size: ", $pool_size, $/;
while ($pool_size < $conf->{CHADO_POOL_SIZE} && $tries--) {
	my $DB_NAME = '_pool_' . lc random_string(8);
	
	#print "NEW DB = ", $DB_NAME, $/;

	unless ($cutils->check_db_exists($DB_NAME)) {
		$cutils->username($DB_NAME);
		$QUIET = 1;
		$cutils->create_db($QUIET);
		my $DONE_DB_NAME = $DB_NAME;
		$DONE_DB_NAME =~ s/^_//;
		#print STDERR  "ALTER DATABASE $DB_NAME RENAME TO $DONE_DB_NAME", $/;
		my $dbh = $cutils->dbh;
		$dbh->do("ALTER DATABASE $DB_NAME RENAME TO $DONE_DB_NAME") or do {
				print STDERR "ERROR: ", $dbh->errstr, $/;
			};
	}
	else {
		#print "DB $DB_NAME already exists...", $/;
	}
	
	$pool_size = $cutils->get_pool_size;
}

exit(0);
