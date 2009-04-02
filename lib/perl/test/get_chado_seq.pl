#!/user/bin/perl -w

use strict;
use Bio::DB::Das::Chado ();
use Data::Dumper;

my $db = Bio::DB::Das::Chado->new(
		-dsn => 'dbi:Pg:dbname=riceannodb;host=dnalc-lab01.cshl.edu',
		-user => 'cornel',
	);

#my @types = $db->types;
#print STDERR Dumper( \@types), $/;

my $seg = $db->segment(-name => 'chr1',
					-start => 150_001,
					-end => 250_000,
				);
#print $seg->start,'-', $seg->stop, $/;
print ">$seg\n";
print $seg->dna, $/;

