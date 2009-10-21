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

sub __retrieve_all {

	__PACKAGE__->retrieve_from_sql ( q{
			1 = 1
			ORDER BY mp_id ASC
		});
}

#-----------------------------------------------------------------------------

1;
