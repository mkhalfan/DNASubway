package DNALC::Pipeline::UserRole;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('user_groups');
__PACKAGE__->columns(Primary => qw/user_id group_id/);

__PACKAGE__->has_a(user_id => 'DNALC::Pipeline::User');
__PACKAGE__->has_a(group_id => 'DNALC::Pipeline::Group');


1;
