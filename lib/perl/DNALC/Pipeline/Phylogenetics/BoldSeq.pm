package DNALC::Pipeline::Phylogenetics::BoldSeq;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_bold_seq');
__PACKAGE__->columns(Primary => qw/project_id sequence_id/);
__PACKAGE__->columns(Essential => qw/bold_id/);

__PACKAGE__->has_a(bold_id => DNALC::Pipeline::Phylogenetics::Bold);

