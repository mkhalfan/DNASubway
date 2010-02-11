#!/usr/bin/perl 

use common::sense;

use DNALC::Pipeline::UserProfile ();

my $tree_root = 2;
my $user_id = 90;

my $data = {
         'q27' => '1111',
		 'q28' => '34',
		 #'q35' => 'alabala',
		 #'q3' => '5',
         'q12' => '39',
         'q26' => 'xyz',
         'q10' => '25'
       };

DNALC::Pipeline::UserProfile->store_user_profile($tree_root, $user_id, $data);

