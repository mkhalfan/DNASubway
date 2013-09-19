#!/usr/bin/perl

# $Id: web_blast.pl,v 1.6 2007/06/06 17:41:09 coulouri Exp $
#
# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#               National Center for Biotechnology Information
#
# This software/database is a "United States Government Work" under the
# terms of the United States Copyright Act.  It was written as part of
# the author's offical duties as a United States Government employee and
# thus cannot be copyrighted.  This software/database is freely available
# to the public for use. The National Library of Medicine and the U.S.
# Government have not placed any restriction on its use or reproduction.
#
# Although all reasonable efforts have been taken to ensure the accuracy
# and reliability of the software and data, the NLM and the U.S.
# Government do not and cannot warrant the performance or results that
# may be obtained by using this software or data. The NLM and the U.S.
# Government disclaim all warranties, express or implied, including
# warranties of performance, merchantability or fitness for any particular
# purpose.
#
# Please cite the author in any work or product based on this material.
#
# ===========================================================================
#
# This code is for example purposes only.
#
# Please refer to http://www.ncbi.nlm.nih.gov/blast/Doc/urlapi.html
# for a complete list of allowed parameters.
#
# Please do not submit or retrieve more than one request every two seconds.
#
# Results will be kept at NCBI for 24 hours. For best batch performance,
# we recommend that you submit requests after 2000 EST (0100 GMT) and
# retrieve results before 0500 EST (1000 GMT).
#
# ===========================================================================
#
# return codes:
#     0 - success
#     1 - invalid arguments
#     2 - no hits found
#     3 - rid expired
#     4 - search failed
#     5 - unknown error
#
# ===========================================================================

use URI::Escape;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Getopt::Long;
use IO::File ();

use strict;

my ($program, $database, $input_file, $output_file, $HELP);

GetOptions(
    'help'  => \$HELP,
    'program=s' => \$program,
    'database=s' => \$database,
    'input_file=s' => \$input_file,
    'output_file=s' => \$output_file,
) or usage();

sub usage {
    print "\nUsage:\n\nweb_blast.pl -p program -d database -o output_file file1 [file2]...\n";
    print "  where program = megablast, blastn, blastp, rpsblast, blastx, tblastn, tblastx\n\n";
    print "  example: web_blast.pl -p blastp -d nr -o x.txt protein.fasta\n";
    print "  example: web_blast.pl -p rpsblast -d cdd -o x.txt protein.fasta\n";
    print "  example: web_blast.pl -p megablast -d nt -o x.txt dna1.fasta dna2.fasta\n";

    exit 1;
}

unless ($program && $database && $input_file) {
    usage();
}

my $encoded_query = '';
my ($rid, $rtoe);

if ($program eq "megablast") {
    $program = "blastn&MEGABLAST=on";
}
elsif ($program eq "rpsblast") {
    $program = "blastp&SERVICE=rpsblast";
}

# read and encode the data
if ($input_file && -f $input_file) {
    open(QUERY,$input_file);
    while(<QUERY>) {
        $encoded_query = $encoded_query . uri_escape($_);
    }
    close QUERY;
}
else {
    print STDERR "Can't open file: ", $input_file, $/;
    usage();
}
    
#$encoded_query .= '&FORMAT_TYPE=Text';
$encoded_query .= '&HITLIST_SIZE=20';

# build the request
my $args = "CMD=Put&PROGRAM=$program&DATABASE=$database&QUERY=" . $encoded_query;

my $ua = LWP::UserAgent->new;

my $service = 'http://www.ncbi.nlm.nih.gov/blast/Blast.cgi';
my $req = new HTTP::Request POST => $service;
$req->content_type('application/x-www-form-urlencoded');
$req->content($args);

# get the response
my $response = $ua->request($req);

# parse out the request id
$response->content =~ /^    RID = (.*$)/m;
$rid=$1;

# parse out the estimated time to completion
$response->content =~ /^    RTOE = (.*$)/m;
$rtoe=$1;

# wait for search to complete
sleep $rtoe;

# poll for results
while (1) {
    sleep 5;

    $req = new HTTP::Request GET => "$service?CMD=Get&FORMAT_OBJECT=SearchInfo&RID=$rid";
    $response = $ua->request($req);

    if ($response->content =~ /\s+Status=WAITING/m) {
        # print STDERR "Searching...\n";
        next;
    }

    if ($response->content =~ /\s+Status=FAILED/m) {
        print STDERR "Search $rid failed; please report to blast-help\@ncbi.nlm.nih.gov.\n";
        exit 4;
    }

    if ($response->content =~ /\s+Status=UNKNOWN/m) {
        print STDERR "Search $rid expired.\n";
        exit 3;
     }

    if ($response->content =~ /\s+Status=READY/m) {
        if ($response->content =~ /\s+ThereAreHits=yes/m) {
            #  print STDERR "Search complete, retrieving results...\n";
            last;
        }
        else {
            print STDERR "No hits found.\n";
            exit 2;
        }
    }

    # if we get here, something unexpected happened.
    exit 5;
} # end poll loop

# retrieve and display results
$req = new HTTP::Request GET => "$service?CMD=Get&FORMAT_TYPE=Text&RID=$rid";
$response = $ua->request($req);

my $outfh = IO::File->new;
unless ($outfh->open($output_file, 'w')) {
    print STDERR "Can't open output file: $output_file\n";
    exit 5;
}

#print STDERR "Got the data\n";
print $outfh $response->content;

exit 0;
