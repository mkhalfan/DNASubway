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
my $version = shift || '2.1.1u3';

my $apps = $api_instance->apps;
my @apps = $apps->find_by_name("cuffdiff-$cluster");
my ($cl) = grep {/$version$/} @apps;
if ($cl) {
    print "Found App ", $cl->name, "\n";
    print STDERR Dumper( $cl ), $/ if DEBUG;
}
else {
    print STDERR  "App [cuffdiff] not found!!", $/;
    exit -1;
}

my $io = $api_instance->io;

my $base_dir = '/' . $api_instance->user;
print "Working in [", $base_dir, "]", $/;

my $job_ep = $api_instance->job;
$job_ep->debug(DEBUG);

my $job_id;

my %params = (
    jobName => "cuffdiff",
    archive => 1,
    archivePath => "/smckay/API_test/cuffdiff/$cluster\-$$",
    processors => 1,
    requestedTime => '01:00:00',
    softwareName => $cl->name,
    query1 => '/smckay/cuffdiff_test/gtf/WT_rep1_transcripts.gtf',
    query2 => '/smckay/cuffdiff_test/gtf/WT_rep2_transcripts.gtf',
    query3 => '/smckay/cuffdiff_test/gtf/hy5_rep1_transcripts.gtf',
    query4 => '/smckay/cuffdiff_test/gtf/hy5_rep2_transcripts.gtf',
    ref_seq => '/shared/iplant_DNA_subway/genomes/arabidopsis_thaliana/genome.fas',
    ref_gtf => '/shared/iplant_DNA_subway/genomes/arabidopsis_thaliana/annotation.gtf',
    sam1_f1 => '/smckay/cuffdiff_test/WT_rep1.bam',
    sam1_f2 => '/smckay/cuffdiff_test/WT_rep2.bam',
    sam2_f1 => '/smckay/cuffdiff_test/hy5_rep1.bam',
    sam2_f2 => '/smckay/cuffdiff_test/hy5_rep2.bam',
    sam3_f1 => '/smckay/cuffdiff_test/hy5_rep1.bam',
    sam3_f2 => '/smckay/cuffdiff_test/hy5_rep2.bam',
    preMrnaFraction => 0.15,
    noFauxReads => 0,
    trim3avgcovThresh => 10,
    intronOverhangTolerance => 10,
    trim3dropoffFrac => 0.1,
    minFragsPerTransfrag => 10,
    libraryType => 'fr-unstranded',
    minIsoformFraction => 0.1,
    upperQuartileNorm => 0,
    overhangTolerance3 => 600,
    maxBundleLength => 3500000,
    smallAnchorFraction => 0.09,
    maxIntronLength => 300000,
    minIntronLength => 50,
    overhangTolerance => 10,
    multiReadCorrect => 0,
    fdr => 0.05,
    minAlignmentCount => 5,
    labels => 'foo,bar,baz',
    compatibleHitsNorm => 0,
    totalHitsNorm => 1,
    poissonDispersion => 1,
    treatAsTimeSeries => 0
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
