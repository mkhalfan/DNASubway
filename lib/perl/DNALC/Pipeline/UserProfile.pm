package DNALC::Pipeline::UserProfile;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);
use Carp;

#use Data::Dumper;

#-----------------------------------------------------------------------------
sub get_question_tree_flat {
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

#-----------------------------------------------------------------------------
sub get_question {
	my ($class, $node_id) = @_;
	return unless $node_id;

	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare('SELECT * FROM user_profile_question WHERE q_id = ?') or do {
					carp 'ERROR preparing query: ', $dbh->errstr;
					return; };
	$sth->execute($node_id) or do {
					carp 'ERROR preparing query: ', $sth->errstr;
					return; };
	my $row = $sth->fetchrow_hashref;
	$sth->finish;
	$row;
}

#-----------------------------------------------------------------------------
# returns hashref version of the tree
#
sub get_question_tree {
	my ($class, $root) = @_;
	$root ||= 1;

	my $tree = DNALC::Pipeline::UserProfile->get_question_tree_flat($root);
	# this could be userd for a building a real tree out of the questions hierarchi
	my %questions = map {
		#$qa{"$_->{q_id}"} = $data->{"q$_->{q_id}"};
				$_->{q_id} => {q => $_, a => {}}
			} grep {$_->{q_type} eq "q" } @$tree;

	# get posible answers for each question
	for (grep {$_->{q_type} eq "a" } @$tree) {
		my $question_id = $_->{q_parent_id};
		$questions{$question_id}->{a}->{$_->{q_id} } = $_;
	}
	return \%questions;
}

#-----------------------------------------------------------------------------
#
sub store_user_profile {
	my ($class, $root, $user_id, $data) = @_;

	my @rows = $class->validate_user_profile_data($root, $data);
	return unless @rows;

	print STDERR  "We should remove all data for this user from the profile answers..", $/;

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

#-----------------------------------------------------------------------------
# returns a list of rows, ready to be inserted into the db
# returns an array or arrayrefs
sub validate_user_profile_data {
	my ($class, $root, $data) = @_;

	my @rows = ();

	my $questions = DNALC::Pipeline::UserProfile->get_question_tree($root);
	my %questions = %$questions;

	#check if the selected answer triggers other question
	for my $qid ( keys %questions)
	{
		my $q = $questions{$qid}->{q};
		my $a = $questions{$qid}->{a};
		if (defined $data->{"q$qid"} && defined $a->{$data->{"q$qid"}} ) {
			my ($atq_id) = grep 
					{ 
						defined $a->{$_}->{q_triggers}			# with trigger
						&& !defined $a->{$a->{$_}->{q_triggers}}# triggered not within answers to the current question
						&& $_ == $data->{"q$qid"}				# answer to this question == this answer
					} keys %$a;

			# if we found the id of the answer that may trigger a question...
			if ($atq_id) {
				my $atq = $a->{$atq_id};
				#print "atq: ", $qid, "/", $atq_id, ' -> ', $atq->{q_triggers}, $/ if $atq;
				my @srows = $class->validate_user_profile_data($atq->{q_triggers}, $data);
				push @rows, @srows if @srows;
			}
		}
	}

	# questions aswered
	my %qa = map {$_ => $data->{"q$_"}} keys %questions;
	#print STDERR Dumper( \%qa ), $/;
	#return;

	for my $qid (keys %qa) {
		next unless defined $qa{$qid};
		my $answer_value = '';
		my @possible_answers = ();
		my $possible_answer = $qa{$qid} ? $questions{$qid}->{a}->{$qa{$qid}} : undef;

		#unless ($possible_answer) {
			#print $qid, ' ', $qa{$qid}, $/;
			#print STDERR Dumper( $questions->{$qid}), $/ if $qid == 37;
		#}

		if (!$possible_answer) {
			if (ref $qa{$qid} eq 'ARRAY') {
			
				#print STDERR Dumper( $questions{$qid}->{a} ), $/;
				#print STDERR  $qid, " => ", $qa{$qid}, $/;
				for (@{$qa{$qid}}) {
					next unless defined $questions{$qid}->{a}->{$_};
					push @possible_answers, $questions{$qid}->{a}->{$_};
				}
			}
			elsif ( ! keys %{$questions->{$qid}->{a}} ) { # no answers, it's just a plain question
				
				#print '##', $qid, ' ', $qa{$qid}, $/;
				#print STDERR '##', Dumper( $questions->{$qid}), $/ if $qid == 37;
				push @possible_answers, $questions->{$qid}->{q};
			}
		}
		else {
			push @possible_answers, $possible_answer;
		}

		for my $possible_answer (@possible_answers) {
			if ($possible_answer) {
				$answer_value = $possible_answer->{q_type} eq 'a' 
								? $possible_answer->{q_label}
								: $data->{"q" . $possible_answer->{q_id}};
				
				# [$question_id, $answer_id, $value]
				push @rows, [ $qid, $possible_answer->{q_id}, $answer_value];

				if ($possible_answer->{q_triggers} && defined $data->{ "q" . $possible_answer->{q_triggers}}) {
					$answer_value = $data->{ "q" . $possible_answer->{q_triggers}};
					
					push @rows, [ $qid, $possible_answer->{q_triggers}, $answer_value || ''];
				}
			}
		}
	}

	return @rows;
}

#-----------------------------------------------------------------------------
# stors directly the answers into user's  profile
# used for simple questions, not found in a tree structure
sub store_user_profile_directly {
	my ($class, $user_id, $data) = @_;

	my $query = 'INSERT INTO user_profile_answer (a_user_id, a_question_id, a_answer_id, a_value)
			VALUES (?, ?, ?, ?)';
	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare($query) or do {
				carp 'ERROR preparing query: ', $dbh->errstr;
				return; };

	for my $key (keys %$data) {
		my $qid = $key;
		if ($qid =~ /^q\d+$/) {
			$qid =~ s/^q//;
		}
		my $q = $class->get_question($qid);
		next unless $q;
		#print STDERR  $qid, ' ', $q->{q_label}, ' = ', $data->{$key}, $/;
		$sth->execute($user_id, $qid, undef, $data->{$key}) or do {
					carp 'ERROR executing query: ', $sth->errstr;
					return; };
	}
}

#-----------------------------------------------------------------------------
sub get_user_institution {
	my ($class, $user_id) = @_;
	my $institution = '';
	return $institution unless $user_id;

	my @qids = ();
	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare_cached(
				q{SELECT q_id FROM user_profile_question WHERE q_id IN (
					SELECT q_triggers FROM user_profile_question WHERE q_parent_id = ?
				) AND q_type = ?}) or do {
					carp 'ERROR preparing query: ', $dbh->errstr;
					return; };
	$sth->execute(12, 'q') or do {
					carp 'ERROR execute query: ', $sth->errstr;
					return; };
	while (my ($id) = $sth->fetchrow_array) {
		push @qids, $id;
	}
	return $institution unless @qids;

	#my $sql = 'SELECT a_question_id, q_label, a_value';
	my $sql = 'SELECT a_value
		FROM user_profile_answer
		LEFT JOIN user_profile_question ON a_question_id = q_id
		WHERE a_user_id = ?
		AND a_question_id IN (';
	my @args = ($user_id);
	for (@qids) {
		$sql .= q{SELECT q_id FROM sub_questions(?)
			WHERE q_type = 'q' AND q_input_type = '' AND lower(q_label) LIKE '%institution%'
			UNION };
		push @args, $_;
	}
	$sql =~ s/UNION $/)/;

	$sth = $dbh->prepare($sql) or do {
					carp 'ERROR preparing query: ', $dbh->errstr;
					return; };

	$sth->execute( @args ) or do {
                    carp 'ERROR executing query: ', $sth->errstr;
                    return; };
	($institution) = $sth->fetchrow_array;
	$sth->finish;
	$institution ||= '';
}

sub user_profile {
	my ($class, $user_id) = @_;
	my %profile = ();
	return %profile unless $user_id;
	my $sql = q{
		SELECT q_parent_id, q_id, q_label AS question, a_value AS answer
			FROM user_profile_answer
			LEFT JOIN user_profile_question ON a_question_id = q_id
			WHERE a_user_id = ?
			AND a_question_id IN (
			  SELECT q_id FROM user_profile_question
			  WHERE q_type = 'q' AND q_parent_id in (1,2, 36, 48)
			)
		ORDER BY q_parent_id, q_order_num, a_answer_id
		};
	my $dbh = $class->getDBH;
	my $sth = $dbh->prepare($sql) or do {
					carp 'ERROR preparing query: ', $dbh->errstr;
					return; };
	$sth->execute($user_id) or do {
                    carp 'ERROR executing query: ', $sth->errstr;
                    return; };
	while (my $answer = $sth->fetchrow_hashref) {
		if (defined $profile{$answer->{question}}) {
			$profile{$answer->{question}} .= ', ' . $answer->{answer};
		}
		else {
			$profile{$answer->{question}} = $answer->{answer};
		}
	}
	$sth->finish;
	wantarray ? %profile : \%profile;

}

1;
