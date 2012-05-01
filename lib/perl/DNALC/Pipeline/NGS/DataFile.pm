package DNALC::Pipeline::NGS::DataFile;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();

__PACKAGE__->table('ngs_data_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_name file_path file_type created/);
__PACKAGE__->sequence('ngs_data_file_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');
__PACKAGE__->has_a(source_id => 'DNALC::Pipeline::NGS::DataSource');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

sub project {
	@_[0]->project_id;
}

sub source {
	@_[0]->source_id;
}

1;

