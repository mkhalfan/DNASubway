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

my $cluster = shift || 'stampede';
my $version = shift || '2.0.8u2';

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
my @apps = $apps->find_by_name("dnalc-tophat-$cluster");
if (@apps > 1) {
    print Dumper [map {$_->id} @apps]
}
my ($cl) = grep {/$version$/} @apps;
if ($cl) {
    print "Found App ", $cl->name, "\n";
    print STDERR Dumper( $cl ), $/ if DEBUG;
}
else {
    print STDERR  "App [tophat] not found!!", $/;
    exit -1;
}

my $io = $api_instance->io;

my $base_dir = '/' . $api_instance->user;
print "Working in [", $base_dir, "]", $/;

my $job_ep = $api_instance->job;
$job_ep->debug(DEBUG);

my $job_id;

my %params = (
    jobName => "tophat-$$",
    archive => 1,
    archivePath => "/smckay/API_test/tophat/$cluster\-$$",
    processors => 1,
    requestedTime => '02:00:00',
    #query1 => '/smckay/fastq/WT_rep1.fastq',
    query1 => '/shared/iplant_DNA_subway/sample_data/fastq/small/WT_rep1.fastq',
    genome => '/shared/iplant_DNA_subway/genomes/arabidopsis_thaliana/genome.fas',
    annotation => '/shared/iplant_DNA_subway/genomes/arabidopsis_thaliana/annotation.gtf',
    softwareName => $cl->name,,
    read_mismatches => 2,
    'max_insertion_length' => '3',
    'mate_inner_dist' => '200',
    'min_intron_length' => '70',
    'min_anchor_length' => '8',
    'max_multihits' => '20',
    'library_type' => 'fr-unstranded',
    'max_deletion_length' => '3',
    'splice_mismatches' => '0',
    'max_intron_length' => '50000',
    'min_isoform_fraction' => '0.15',
    'mate_std_dev' => '20',
    'segment_length' => '20',
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
    last if $stat =~ /FINISHED|FAILED/;
    $i--;
    sleep 30;
}

system "/home/smckay/stampede/util/status.sh $job_id";
