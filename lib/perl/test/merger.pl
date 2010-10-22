#!/usr/bin/perl

use common::sense;

use DNALC::Pipeline::Process::Merger ();
use Data::Dumper;

my $dir = "/var/www/vhosts/pipeline.dnalc.org/var/projects/greenline/fasta";
my $consensus_dir = "$dir/consensus";
mkdir $consensus_dir;

my $merger = DNALC::Pipeline::Process::Merger->new($dir);

$merger->run(
		input_files => ["$dir/03.fasta", "$dir/04.fasta"],
		outfile => $consensus_dir . "/outfile_1.txt",
		outseq => $consensus_dir . "/merged_seq_1.txt",
		sreverse1 => '',
		pretend => 0,
		debug => 1,
	);

print STDERR Dumper( $merger ), $/;

$merger->build_consensus(
		$consensus_dir . "/outfile_1.txt",
		$consensus_dir . "/merged_seq_1.txt",
		$consensus_dir . "/processed_consensus_1.txt"
	);

print STDERR  $consensus_dir . "/processed_consensus_1.txt", $/;


