package DNALC::Pipeline::Phylogenetics::Blast;

#use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_blast');
__PACKAGE__->columns(Primary => qw/blast_id/);
__PACKAGE__->columns(Essential => qw/project_id sequence_id crc/);
__PACKAGE__->columns(Other => qw/output created/);
__PACKAGE__->sequence('phy_blast_blast_id_seq');

#__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

1;
