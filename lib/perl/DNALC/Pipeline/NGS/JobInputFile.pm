package DNALC::Pipeline::NGS::JobInputFile;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job_input_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/job_id file_id project_id app_input_id/);
__PACKAGE__->sequence('ngs_job_input_file_id_seq');

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

__END__

package main;
use strict;
use warnings;

my $file_id = 96;

my $jif = DNALC::Pipeline::NGS::JobInputFile->create({file_id => $file_id, project_id => 16, job_id => 91});

print $jif->file->file_name, $/ if $jif;

