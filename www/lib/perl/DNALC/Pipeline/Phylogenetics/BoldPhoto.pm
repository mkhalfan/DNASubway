package DNALC::Pipeline::Phylogenetics::BoldPhoto;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_bold_photo');
__PACKAGE__->columns(Primary => qw/photo_id/);
__PACKAGE__->columns(Essential => qw/bold_id project_id photo photo_thumb created/);

__PACKAGE__->has_a(bold_id => DNALC::Pipeline::Phylogenetics::Bold);

__PACKAGE__->sequence('phy_bold_photo_photo_id_seq');


1;

