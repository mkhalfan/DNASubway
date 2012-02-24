package DNALC::Pipeline::MasterProject;

use base qw(DNALC::Pipeline::DBI);

use Class::DBI::Pager;

__PACKAGE__->table('master_project');
__PACKAGE__->columns(Primary => qw/mp_id/);
__PACKAGE__->columns(Essential => qw/user_id project_id project_type public/);

__PACKAGE__->sequence('master_project_mp_id_seq');


#-----------------------------------------------------------------------------
__PACKAGE__->set_sql(count_per_user => q{
		SELECT count(*) FROM __TABLE__ WHERE user_id = ?
	});


#-----------------------------------------------------------------------------
__PACKAGE__->set_sql(get_sorted => q{
	SELECT mp.mp_id, mp.project_type, 
		u.name_first || ' ' || u.name_last AS full_name, mp.project_id, 
		CASE mp.project_type 
			WHEN 'annotation' THEN p.name
			WHEN 'target' THEN tp.name
			WHEN 'phylogenetics' THEN pp.name
		END AS name,
		CASE mp.project_type
			WHEN 'annotation' THEN p.organism
			WHEN 'target' THEN tp.organism
			WHEN 'phylogenetics' THEN pp.name
		END AS organism
	FROM master_project mp
	LEFT JOIN project p ON mp.project_id = p.project_id
	LEFT JOIN target_project tp ON mp.project_id = tp.tpid
	LEFT JOIN phy_project pp ON mp.project_id = pp.id
	LEFT JOIN users u ON mp.user_id = u.user_id
	WHERE CASE mp.project_type 
		WHEN 'annotation' THEN p.project_id 
		WHEN 'target' THEN tp.tpid 
		WHEN 'phylogenetics' THEN pp.id
	END IS NOT NULL 
		%s
	ORDER BY %s
	});

sub get_public_sorted {
	my ($class, $args) = @_;

	my $order_by = $args->{order_by} || 'mp.mp_id DESC';
	my $where_str = 'AND mp.public = true ';
	my @params = ();
	
	if ($args->{where} && $args->{where}) {
		if (defined $args->{where}->{user_name}) {
			my $name = lc $args->{where}->{user_name};
			$where_str .= "AND (lower(u.name_first) like ? OR lower(u.name_last) like ?) ";
			push @params, ('%' . $name . '%', '%' . $name . '%');
		}

		if (defined $args->{where}->{organism}) {
			$where_str .= "AND CASE mp.project_type "
						. "  WHEN 'annotation' THEN lower(p.organism) "
						. "  WHEN 'target' THEN lower(tp.organism) "
						. "  WHEN 'phylogenetics' THEN lower(pp.type) "
						. "END like ? ";
			push @params,  '%' . $args->{where}->{organism} . '%';
		}

		if (defined $args->{where}->{title}) {
			$where_str .= "AND CASE mp.project_type "
						. "  WHEN 'annotation' THEN lower(p.name) "
						. "  WHEN 'target' THEN lower(tp.name) "
						. "  WHEN 'phylogenetics' THEN lower(pp.name) "
						. "END like ? ";
			push @params,  '%' . $args->{where}->{title} . '%';
		}

	}
	#print STDERR  $where_str, $/;

	my $sth = $class->sql_get_sorted($where_str, $order_by);
	$sth->execute(@params);
	return $class->sth_to_objects($sth);
}

sub get_mine_sorted {
	my ($class, $args) = @_;
	my $order_by = $args->{order_by} || 'mp.mp_id DESC';
	my $sth = $class->sql_get_sorted('AND mp.user_id = ?', $order_by);
	$sth->execute($args->{user_id});
	return $class->sth_to_objects($sth);
}
#-----------------------------------------------------------------------------


1;
