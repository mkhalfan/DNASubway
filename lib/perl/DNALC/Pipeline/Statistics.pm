package DNALC::Pipeline::Statistics;


use base qw(DNALC::Pipeline::DBI);


__PACKAGE__->set_sql( task_count_registered_users => q{
		SELECT count(*) AS num, t.task_id, t.name
		FROM workflow w
		JOIN task t ON w.task_id = t.task_id
		LEFT JOIN users u ON w.user_id = u.user_id 
		WHERE w.status_id = 2
			AND u.user_id IS NOT NULL
			AND u.username NOT LIKE 'guest%%'
			AND t.enabled = TRUE
		GROUP BY t.task_id, t.name
		ORDER BY num DESC
	});

sub count_task_registered_users {
	my ($class) = @_;

	my @stats = ();

	my $sth = $class->sql_task_count_registered_users;
	$sth->execute;
	while (my $row = $sth->fetchrow_hashref) {
		push @stats, $row;
	}
	$sth->finish;

	return @stats;
}

__PACKAGE__->set_sql( task_count_guest_users => q{
		SELECT count(*) AS num, t.task_id, t.name
		FROM workflow w
		JOIN task t ON w.task_id = t.task_id
		LEFT JOIN users u ON w.user_id = u.user_id 
		WHERE w.status_id = 2
			AND (u.user_id IS NULL
				OR u.username LIKE 'guest%%')
			AND t.enabled = TRUE
		GROUP BY t.task_id, t.name
		ORDER BY num DESC
	});
sub count_task_guest_users {
	my ($class) = @_;

	my @stats = ();

	my $sth = $class->sql_task_count_guest_users;
	$sth->execute;
	while (my $row = $sth->fetchrow_hashref) {
		push @stats, $row;
	}
	$sth->finish;

	return @stats;
}

__PACKAGE__->set_sql( count_registered_users => q{
		SELECT count(*)
		FROM users
		WHERE username NOT LIKE 'guest%%'
	});
sub count_registered_users {
	my ($class) = @_;

	return $class->sql_count_registered_users->select_val;
}

__PACKAGE__->set_sql( group_by_occupation_institution => q{
		SELECT count(*) AS num, a_value,
			CASE WHEN a_question_id = 37 THEN 'Student' WHEN a_question_id = 49 THEN 'Educator' END AS occupation
		FROM user_profile_answer
		LEFT JOIN user_profile_question ON a_question_id = q_id
		WHERE a_question_id IN (
			SELECT q_id FROM sub_questions(36)
			WHERE q_type = 'q' AND q_input_type = '' AND lower(q_label) LIKE '%institution%'
			UNION
			SELECT q_id FROM sub_questions(48)
			WHERE q_type = 'q' AND q_input_type = '' AND lower(q_label) LIKE '%institution%'
		)
		GROUP BY occupation, a_value
		ORDER BY num;
	});

__PACKAGE__->set_sql( group_by_occupation => q{
		SELECT count(*) AS num, CASE WHEN a_value != '' THEN a_value ELSE '-' END AS value
		FROM user_profile_answer
		LEFT JOIN user_profile_question ON a_question_id = q_id
		WHERE a_question_id IN (12)
			AND a_value != 'Other'
		GROUP BY value
		ORDER BY num DESC
	});
1;

