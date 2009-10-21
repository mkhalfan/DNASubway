package DNALC::Pipeline::TargetGenome;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('target_genome');
__PACKAGE__->columns(Primary => qw/genome_id/);
__PACKAGE__->columns(Essential => qw/organism note clade active /);

__PACKAGE__->has_many( projects => ['DNALC::Pipeline::TargetRole' => 'tpid']);

1;
