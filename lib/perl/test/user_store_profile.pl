#!/usr/bin/perl 

use common::sense;

use DNALC::Pipeline::UserProfile ();
use Data::Dumper;

my $tree_root = 2;
my $user_id = 90;

my $data0 = {'q27' => '1111',
		 'q28' => '34',
		 'q35' => 'alabala',
		 'q3' => '5',
         'q12' => '39',
         'q26' => 'xyz',
         'q10' => '25' };
my $data = {
          'q35' => 'romales',
          'q10' => '20',
          'q26' => '',
          'q27' => '',
          'q28' => '34',
          'q3' => '5',
          'q37' => 'nume scoala',
          'q12' => '39',
          'q47' => 'tip de scoală',
          'q38' => '46'
        };

#DNALC::Pipeline::UserProfile->store_user_profile($tree_root, $user_id, $data);
my @rows = DNALC::Pipeline::UserProfile->validate_user_profile_data($tree_root, $data);
for my $r (@rows) {
	print join "\t", $user_id, @$r, $/;
}

my $t = DNALC::Pipeline::UserProfile->get_question_tree($tree_root);
my $q_id = 12;
my $q  = $t->{$q_id}->{q};
my $ah = $t->{$q_id}->{a};
my @aa = map {$ah->{$_}} sort { $ah->{$a}->{q_order_num} <=> $ah->{$b}->{q_order_num} } keys %$ah;

my (@x) = grep {
			$_->{q_triggers} && !defined $ah->{ $_->{q_triggers} }
		} @aa;
#print STDERR "anwer thet triggers question = ", Dumper( @x ), $/;
print join ',', map { $_->{q_triggers} . ':' . $_->{q_id} } @x;

