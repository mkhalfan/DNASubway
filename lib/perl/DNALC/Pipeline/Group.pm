package DNALC::Pipeline::Group;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('groups');
__PACKAGE__->columns(Primary => 'group_id');
__PACKAGE__->columns(Essential => qw/group_name info created/);
__PACKAGE__->sequence('groups_group_id_seq');

__PACKAGE__->has_many(users => [ 'DNALC::Pipeline::UserRole' => 'user_id' ]);



1;

