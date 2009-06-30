#!/usr/bin/perl 

use strict;
use warnings;

use DNALC::Pipeline::ProjectManager ();
use DNALC::Pipeline::App::Utils ();

use Data::Dumper;

my $uid = 54;
$ENV{GMOD_ROOT} = '/usr/local/gmod';
#-----------------------------------------------------------------------------
my $input_file = '/home/cornel/work/10k/A.fasta';
my $organism = 'Arabidopsis thaliana';
#my $common_name = 'daffodil';
my $common_name = 'mouse-ear cress';
#-----------------------------------------------------------------------------
my $p_name	= 'Some test41212121200009';
my $p_clade = 'd';
my $seq_src = 'paste';
my $sample_id = '3';

my $pm = DNALC::Pipeline::ProjectManager->new;
my $samples = $pm->config->{samples};

## data/fasta sources
#1. upload => save to a local file
#2. sample => copy sample file && apply some changes
#3. paste => save the text to a local file
#4. gene bank => get the sequence => save it into a file


my $data_file = $input_file;
if ($seq_src eq 'sample') {
	my $samples_dir = $pm->config->{samples_dir};
	my ($sample) = grep {$_->{id} == $sample_id} @$samples;
	if (!$sample || $sample->{organism} ne $organism || $sample->{common_name} ne $common_name) {
		die "Sample organism was not found!!\n";
	}
	$data_file = $samples_dir . '/' . $sample->{id} . '/fasta.fa';
}
elsif ($seq_src eq 'paste') {
	#save data into a file...
}


# process file
my $rc = DNALC::Pipeline::App::Utils->process_input_file($data_file);
if ($rc->{status} eq 'success') {
	my $x = $pm->create_project ({
				user_id => $uid,
				seq => $rc->{seq},
				name => $p_name,
				organism => $organism,
				common_name => $common_name,
				sample => $sample_id,
				clade => $p_clade,
			});
	#print STDERR Dumper( $x ), $/;
	print STDERR  "New PID = ", $pm->project, $/;
}

#print STDERR Dumper( $pm ), $/;
