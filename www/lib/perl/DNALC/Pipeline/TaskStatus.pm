package DNALC::Pipeline::TaskStatus;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('task_status');
__PACKAGE__->columns(Primary => qw/status_id/);
__PACKAGE__->columns(Essential => qw/name/);

1;


