#!/usr/bin/perl -w
use strict;
my $cluster = shift || die "I need a cluster name\n";
my $status  = uc(shift) || die "Cowardly: I need a status to kill\n";

open IN, qq(curl  -sku "\$IPLANTUSER:\$TOKEN" https://foundation.iplantc.org/apps-v1/jobs/list | json_xs | grep '"status"\\|"id"\\|"software"' | grep -v success | perl -pe  's/^\\s+//' |sed 's/"sta/\\n"sta/' |);

my ($stat,$id,$app);
while (<IN>) {
    chomp;
    if (/"status" : "(\S+)"/) {
	$stat = $1;
    }
    if (/"id" : (\d+)/) {
	$id = $1;
    }
    if (/"software" : "(\S+)"/) {
	$app = $1
    }

    if ($stat && $id && $app) {
	if ($stat eq $status && $app =~ /$cluster/) {
	    print "killing $app...\n";
	    print "$status $app\n";
	    print `kill.sh $id`;
	}
	($stat,$id,$app) = erase();
    }
}


sub erase {
    return (undef,undef,undef);
}

__END__
"status" : "ARCHIVING_FINISHED",
"id" : 3033,
"software" : "muscle-ranger-2.0",

"status" : "PENDING",
"id" : 9519,
"software" : "dnalc-ping-stampede-0.0001",

"status" : "PENDING",
"id" : 9539,
"software" : "dnalc-fastqc-stampede-0.10.1u1",

