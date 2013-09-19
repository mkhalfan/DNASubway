package DNALC::Pipeline::TargetRole;

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('target_project_genome');
__PACKAGE__->columns(Primary => qw/tpid genome_id/);

__PACKAGE__->has_a(genome_id => 'DNALC::Pipeline::TargetGenome');
__PACKAGE__->has_a(tpid => 'DNALC::Pipeline::TargetProject');

1;
