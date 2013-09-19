package DNALC::Pipeline::Task;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('task');
__PACKAGE__->columns(Primary => 'task_id');
__PACKAGE__->columns(Essential => qw/name enabled/);

1;


