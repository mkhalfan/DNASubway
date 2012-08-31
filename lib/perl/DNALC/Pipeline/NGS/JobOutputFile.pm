package DNALC::Pipeline::NGS::JobOutputFile;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job_output_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/job_id file_id project_id/);
__PACKAGE__->sequence('ngs_job_output_file_id_seq');

__PACKAGE__->has_a(file_id => 'DNALC::Pipeline::NGS::DataFile');
__PACKAGE__->has_a(job_id => 'DNALC::Pipeline::NGS::Job');
__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');

sub file {
	shift->file_id;
}

sub job {
	shift->job_id;
}


1;



