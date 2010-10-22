#!/usr/bin/perl 

use common::sense;
use DNALC::Pipeline::Process::Merger ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::App::Utils ();
use Bio::AlignIO ();
use IO::File;
use Data::Dumper;

my $data = [{
            'pair' => '0',
            'ch' => 1,
            'id' => '01.fasta'
          },{
            'pair' => '0',
            'ch' => 0,
            'id' => '02.fasta'
          },{
            'pair' => '1',
            'ch' => 0,
            'id' => '03.fasta'
          },{
            'pair' => '1',
            'ch' => 1,
            'id' => '04.fasta'
          }];

my $gcf = DNALC::Pipeline::Config->new->cf("GREENLINE");
my $dir = $gcf->{PROJECTS_DIR} . '/fasta';

my $merger = DNALC::Pipeline::Process::Merger->new($dir);

my $work_dir = $dir . '/consensus';

my @pairs = ();
for my $item (@$data) {
	my $pair = $item->{pair};
	my $seq_file = $item->{id};
	$seq_file =~ s/\///g;
	$seq_file = $dir . '/' . $seq_file;

	if (-f $seq_file && $pair =~ /^\d+$/) {
		if (defined $pairs[$pair]) {
			push @{$pairs[$pair]}, {seq => $seq_file, rc => $item->{ch}, id => $item->{id}};
		}
		else {
			$pairs[$pair] = [{seq => $seq_file, rc => $item->{ch}, id => $item->{id}}];
		}
	}
}

print STDERR Dumper( \@pairs ), $/;
#DNALC::Pipeline::App::Utils->remove_dir($work_dir);
#mkdir $work_dir;

my $pair_cnt = 1;
for my $pair (@pairs) {
	next unless ('ARRAY' eq ref ($pair) && scalar @$pair == 2);
	#print $pair, $/;
	my @args = ();
	my @to_reverse = ();
	my $cnt = 1;
	for my $item (@$pair) {
		push @args, $item->{seq};
		push @to_reverse, "sreverse$cnt" if $item->{rc};
		$cnt++;
	}
	#my $n_outfile = $work_dir . "/n_outfile_$pair_cnt.txt";
	my $outfile = $work_dir . "/outfile_$pair_cnt.txt";
	my $merged_seq_file = $work_dir . "/merged_seq_$pair_cnt.txt";

	my %options = (
			pretend => 0,
			debug => 0,
			input_files => \@args,
			outfile => $work_dir . "/outfile_$pair_cnt.txt",
			outseq => $work_dir . "/merged_seq_$pair_cnt.txt",
		);
	for (@to_reverse) {
		$options{$_} = '',
	}
	#print STDERR Dumper( \%options), $/;
	$merger->run( %options );
	#print STDERR  $merger->{exit_status}, $/;
	#last;

	$merger->build_consensus(
			$work_dir . "/outfile_$pair_cnt.txt",
			$work_dir . "/merged_seq_$pair_cnt.txt",
			$work_dir . "/processed_consensus_$pair_cnt.txt",
		);

	print STDERR $work_dir . "/processed_consensus_$pair_cnt.txt", $/;
	$pair_cnt++;
}


