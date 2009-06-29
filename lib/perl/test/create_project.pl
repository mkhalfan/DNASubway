#!/usr/bin/perl 

use strict;
use warnings;

use DNALC::Pipeline::ProjectManager ();
use DNALC::Pipeline::App::Utils ();

use Data::Dumper;

my $uid = 54;
#-----------------------------------------------------------------------------
my $input_file = '/home/cornel/work/10k/A.fasta';
my $organism = 'Narcissus pseudonarcissus';
#my $common_name = 'daffodil';
my $common_name = 'mouse-ear cress';
#-----------------------------------------------------------------------------
my $p_name = 'Some test2';
my $p_clade= 'd';
my $sample = '';


## data/fasta sources
#1. upload => save to a local file
#2. sample => copy sample file && apply some changes
#3. paste => save the text to a local file
#4. gene bank => get the sequence => save it into a file


my $data_file = $input_file;

my $pm = DNALC::Pipeline::ProjectManager->new;

# process file
my $rc = DNALC::Pipeline::App::Utils->process_input_file($data_file);
if ($rc->{status} eq 'success') {
	my $x = $pm->create_project ({
				user_id => $uid,
				seq => $rc->{seq},
				name => $p_name,
				organism => $organism,
				common_name => $common_name,
				sample => $sample,
				clade => $p_clade,
			});
	print STDERR Dumper( $x ), $/;
}

print STDERR Dumper( $pm ), $/;
