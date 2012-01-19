package DNALC::Pipeline::Phylogenetics::BlastRun;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_blast_run');
__PACKAGE__->columns(Primary => qw/run_id/);
__PACKAGE__->columns(Other => qw/bid created/);

#__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

1;

