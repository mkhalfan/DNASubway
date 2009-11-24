package DNALC::Pipeline::MasterProject;

use POSIX ();
use File::Path;

use base qw(DNALC::Pipeline::DBI);

use Class::DBI::Plugin::AbstractCount;
use Class::DBI::Plugin::Pager;


__PACKAGE__->table('master_project');
__PACKAGE__->columns(Primary => qw/mp_id/);
__PACKAGE__->columns(Essential => qw/user_id project_id project_type/);

__PACKAGE__->sequence('master_project_mp_id_seq');


__PACKAGE__->set_sql('get_all', q{
		SELECT mp_id AS mp_id, mp.user_id AS user_id, mp.project_id AS project_id, mp.project_type AS project_type
		FROM master_project mp
		LEFT JOIN target_project tp ON mp.project_id = tp.tpid
		LEFT JOIN project p ON mp.project_id = p.project_id
		WHERE p.project_id is NOT NULL OR tpid IS NOT NULL
		ORDER BY mp_id DESC}
	);

sub get_all {
	print STDERR  "xxxxxxxxxxxxxxxxxx", $/;
	my $sth = __PACKAGE__->sql_get_all;
	$sth->execute;
	return __PACKAGE__->sth_to_object($sth);
}

#-----------------------------------------------------------------------------
__PACKAGE__->set_sql(count_per_user => q{
		SELECT count(*) FROM __TABLE__ WHERE user_id = ?
	});

1;
