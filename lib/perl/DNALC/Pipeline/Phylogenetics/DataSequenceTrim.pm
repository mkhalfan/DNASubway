package DNALC::Pipeline::Phylogenetics::DataSequenceTrim;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_trim');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/left_trim right_trim start_pos end_pos/);

#__PACKAGE__->has_a(id => 'DNALC::Pipeline::Phylogenetics::DataSequence');


1;
