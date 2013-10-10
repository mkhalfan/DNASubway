#!/usr/bin/perl
use strict;

use lib "/home/$ENV{USER}/lib";
use lib "/home/$ENV{USER}/lib/perl5";

unless ($ENV{IPLANTUSER} && $ENV{TOKEN}) {
    print << 'DEATH';

Error: Before running the test script, set the environmental variables $IPLANTUSER and $TOKEN.

export IPLANTUSER=<your iPlant user id>
export TOKEN=<your iPlant password or token>

DEATH
}


use common::sense;
use IO::File ();
use File::Spec ();
use iPlant::FoundationalAPI::Constants ':all';
use iPlant::FoundationalAPI ();
use Data::Dumper;
use File::Basename;

use constant DEBUG => 0;
use constant iPLANT_USER  => $ENV{IPLANTUSER};
use constant iPLANT_TOKEN => $ENV{TOKEN};

my $cluster = shift || 'stampede';

print "Logging on as user $ENV{IPLANTUSER}\n";

my $api_instance = iPlant::FoundationalAPI->new(
    debug => DEBUG,
    user  => iPLANT_USER,
    token => shift || iPLANT_TOKEN,
    );

die "Can't auth.." unless $api_instance->auth;
if ($api_instance->token eq kExitError) {
    print STDERR "Can't authenticate!" , $/;
}

print "Token: ", $api_instance->token, "\n";

my $apps = $api_instance->apps;
my ($cl) = $apps->find_by_name("tassel_mlm-$cluster");
if ($cl) {
    print "Found App ", $cl->name, "\n";
    print STDERR Dumper( $cl ), $/ if DEBUG;
}
else {
    print STDERR  "App [tassel] not found!!", $/;
    exit -1;
}

my $io = $api_instance->io;

my $base_dir = '/' . $api_instance->user;
print "Working in [", $base_dir, "]", $/;

my $job_ep = $api_instance->job;
$job_ep->debug(DEBUG);

my $job_id;
my $job_name = 'tassel'.int(rand()*1000);

my %params = (
    jobName => $job_name,
    archive => 1,
    archivePath => "/smckay/API_test/tassel/$job_name",
    processors => 1,
    requestedTime => '1:00:00',
    softwareName => $cl->name,
    population => '/shared/KBase_staging/tassel/mdp_population_structure.txt',
    traits => '/shared/KBase_staging/tassel/mdp_traits.txt',
    genotype => '/shared/KBase_staging/tassel/mdp_genotype.hmp.txt',
    kinship => '/shared/KBase_staging/tassel/mdp_kinship.txt',
    export => 'mlm',
    filterAlignMinFreq => '0.05',
    mlmCompressionLevel => 'Optimum',
    mlmMaxP => '1',
    mlmVarCompEst => 'P3D'
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




