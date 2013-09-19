#!/usr/bin/perl -w

use strict;

use lib ("/var/www/lib/perl");

use Getopt::Long;
use DNALC::Pipeline::Phylogenetics::Bold();
use DNALC::Pipeline::App::Phylogenetics::GBManager();

my $id;
GetOptions (
	"id=i"	=> \$id
);

my $usage = "./submit_to_gb.pl -id xx [xx is the id number of the submission you would like to attempt]";

$id or die $usage;

my $record = DNALC::Pipeline::Phylogenetics::Bold->retrieve($id);
unless ($record){
	print "There is no submission found with ID $id. I am ending. Please try again with a different ID. \n";
	exit;
}
if ($record->status eq 'Passed With Warnings' || $record->status eq 'Passed validation'){
	print "You are trying to submit a record which has already been submitted and passed validation, I cannot process this submission, sorry. \n";
	exit;
}

my $gbm = DNALC::Pipeline::App::Phylogenetics::GBManager->new;
my $st = $gbm->run($record);

if ($st->{status} eq 'success') {
	print "This record was submitted sucecssfully\n";
}
elsif ($st->{status} eq 'error') {
	print "Failed to submit record $id. Error: $st->{message}\n";
	$record->status("FAILED: " . $st->{message});
	$record->update;
}
else {
	print "Something went wrong, no response from GBManager...\n";
}

