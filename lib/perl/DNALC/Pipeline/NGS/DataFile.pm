package DNALC::Pipeline::NGS::DataFile;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
#use DNALC::Pipeline::NGS::DataFileTrimmed ();

__PACKAGE__->table('ngs_data_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_name file_path file_type 
									is_input qc_file_id trimmed_file_id created/);
__PACKAGE__->sequence('ngs_data_file_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');
__PACKAGE__->has_a(source_id => 'DNALC::Pipeline::NGS::DataSource');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

sub project {
	$_[0]->project_id;
}

sub source {
	$_[0]->source_id;
}

sub trimmed_file {
	my $file = shift;
	return __PACKAGE__->retrieve($file->trimmed_file_id);
}

sub qc_report {
	my $file = shift;
	return unless $file->qc_file_id;
	
	my $qcf = DNALC::Pipeline::NGS::DataFile->retrieve($file->qc_file_id);
	return $qcf->file_path;
}

1;

