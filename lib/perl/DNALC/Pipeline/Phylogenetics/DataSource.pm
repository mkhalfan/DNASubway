package DNALC::Pipeline::Phylogenetics::DataSource;

#use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();
#use Data::Dumper;

__PACKAGE__->table('phy_data_source');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/name project_id accession/);
__PACKAGE__->sequence('phy_data_source_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');


1;