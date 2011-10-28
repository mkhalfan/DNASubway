package DNALC::Pipeline::NGS::DataSource;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_data_source');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/type note/);
__PACKAGE__->sequence('ngs_data_source_id_seq');

#__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NSG::Project');


1;




