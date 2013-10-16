#!/usr/bin/perl
use strict;
use common::sense;

use lib '/home/smckay/lib';

use AnyEvent;
use IO::File ();
use File::Spec ();
use iPlant::FoundationalAPI::Constants ':all';
use iPlant::FoundationalAPI ();
use Data::Dumper;
use File::Basename;

use constant DEBUG => 0;
use constant iPLANT_USER  => $ENV{USER};
use constant iPLANT_TOKEN => $ENV{TOKEN};

my $api_instance = iPlant::FoundationalAPI->new(
    debug => DEBUG,
    user  => iPLANT_USER,
    token => iPLANT_TOKEN,
    );

die "Can't auth.." unless $api_instance->auth;
if ($api_instance->token eq kExitError) {
    print STDERR "Can't authenticate!" , $/;								
}

print "Token: ", $api_instance->token, "\n";

my $cluster = shift || 'stampede';
my $version = shift || '2.1.1';

my $apps = $api_instance->apps;
my @apps = $apps->find_by_name("cuffmerge-$cluster");
my ($cl) = grep {/$version$/} @apps;
if ($cl) {
    print "Found App ", $cl->name, "\n";
    print STDERR Dumper( $cl ), $/ if DEBUG;
}
else {
    print STDERR  "App [cuffmerge] not found!!", $/;
    exit -1;
}

my $io = $api_instance->io;

my $base_dir = '/' . $api_instance->user;
print "Working in [", $base_dir, "]", $/;

my $job_ep = $api_instance->job;
$job_ep->debug(DEBUG);

my $job_id;

my %params = (
    jobName => "cuffmerge",
    archive => 1,
    archivePath => "/smckay/API_test/cuffmerge/$cluster\-$$",
    processors => 1,
    requestedTime => '01:00:00',
    softwareName  => $cl->name,
    ref_seq => "/shared/iplant_DNA_subway/genomes/arabidopsis_thaliana/genome.fas",
    query1 => "/smckay/cufflinks_test/hy5_rep1-fx386-th900-cl96.gtf",
    query2 => "/smckay/cufflinks_test/hy5_rep2-fx920-th856-cl55.gtf",
    query3 => "/smckay/cufflinks_test/WT_rep1-fx282-th294-cl44.gtf",
    query4 => "/smckay/cufflinks_test/WT_rep2-fx790-th268-cl31.gtf"
    );

my $job = $job_ep->submit_job($cl, %params), $/;
if ($job != kExitError) {
    $job_id = $job->{data}->{id};
    print STDERR  "JOB_ID: ", $job_id, $/;
}
else {
    print STDERR  "Failed to submit job..", $/;
}

unless ($job_id) {
    die "Job not submitted..\n", Dumper $job;
}

print STDERR  "Polling for job status..", $/;

my $i = 20;

while ($i) {
    my $st = $job_ep->job_details($job_id);
    my $stat = $job_id. "\t". $st->{status}. "\t" . `date`;
    print $stat;
    last if $stat =~ /FINISHED/;
    $i--;
    sleep 30;
}

