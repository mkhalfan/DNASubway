package DNALC::Pipeline::NGS::Job;

use POSIX ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/api_job_id project_id task_id user_id status_id deleted/);
__PACKAGE__->columns(Other => qw/duration created/);
__PACKAGE__->sequence('ngs_job_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');

__PACKAGE__->has_many(job_params => 'DNALC::Pipeline::NGS::JobParam');

#__PACKAGE__->add_trigger('before_create' => sub {
#my $self = shift;
#$self->{id} = $self->_get_next_id;
#);

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


sub _get_next_id {
	my $class = shift;
	$class->sql_next_id->select_val;
}

1;
