package DNALC::Pipeline::UserProfile;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);
use Carp;

#use POSIX ();
#use Digest::MD5 ();
#use DNALC::Pipeline::Utils qw(random_string);
#use Data::Dumper;

#----------------------------
sub get_question_tree {
	my ($class, $root) = @_;
	$root ||= 1;
	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare('SELECT * FROM sub_questions( ? )') or do {
					carp 'ERROR preparing query: ', $dbh->errstr;
					return; };
	$sth->execute($root) or do {
					carp 'ERROR preparing query: ', $sth->errstr;
					return; };
	my @tree = ();
	while (my $row = $sth->fetchrow_hashref) {
		push @tree, $row;
	}
	$sth->finish;
	\@tree;
}

sub store_user_profile {
	my ($class, $root, $user_id, $data) = @_;

	my @rows = $class->validate_user_profile_data($root, $data);
	return unless @rows;

	my $query = 'INSERT INTO user_profile_answer (a_user_id, a_question_id, a_answer_id, a_value)
			VALUES (?, ?, ?, ?)';
	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare($query) or do {
				carp 'ERROR preparing query: ', $dbh->errstr;
				return; };

	for my $r (@rows) {
		#print join "\t", $user_id, @$r, $/;
		$sth->execute($user_id, $r->[0], $r->[1], $r->[2]) or do {
					carp 'ERROR executing query: ', $sth->errstr;
					return; };
	}
}

# return a list of rows, ready to be inserted into the db
sub validate_user_profile_data {
	my ($class, $root, $data) = @_;

	my $tree = DNALC::Pipeline::UserProfile->get_question_tree($root);
	my %qa = ();

	# this could be userd for a building a real tree out of the questions hierarchi
	my %questions = map {
				$qa{"$_->{q_id}"} = $data->{"q$_->{q_id}"};
				$_->{q_id} => {q => $_, a => {}}
			} grep {$_->{q_type} eq "q" } @$tree;

	# get posible answers for each question
	for (grep {$_->{q_type} eq "a" } @$tree) {
		my $question_id = $_->{q_parent_id};
		$questions{$question_id}->{a}->{$_->{q_id} } = $_;
	}
	
	my @rows = ();
	for my $qid (keys %qa) {
		next unless defined $qa{$qid};
		my $answer_value = '';
		my $possible_answer = $qa{$qid} ? $questions{$qid}->{a}->{$qa{$qid}} : undef;
		if ($possible_answer) {
			$answer_value = $possible_answer->{q_label};
			
			# [$question_id, $answer_id, $value]
			push @rows, [ $qid, $qa{$qid}, $possible_answer->{q_label}];

			if ($possible_answer->{q_triggers} && defined $data->{ "q" . $possible_answer->{q_triggers}}) {
				$answer_value = $data->{ "q" . $possible_answer->{q_triggers}};
				
				push @rows, [ $qid, $possible_answer->{q_triggers}, $answer_value || ''];
			}
		}
	}

	return @rows;
}

1;
