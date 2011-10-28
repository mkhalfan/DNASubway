package DNALC::Pipeline::NGS::JobParam;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job_param');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/job_id type name value/);
__PACKAGE__->sequence('ngs_job_param_id_seq');

__PACKAGE__->has_a(job_id => 'DNALC::Pipeline::NGS::Job');

1;
