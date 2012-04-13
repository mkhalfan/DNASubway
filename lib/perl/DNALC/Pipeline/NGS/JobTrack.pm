package DNALC::Pipeline::NGS::JobTrack;

use base qw(DNALC::Pipeline::DBI);
use POSIX qw/strftime/;

__PACKAGE__->table('ngs_job_track');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/job_id api_job_id user_id token api_status tracker_status updated/);
__PACKAGE__->sequence('ngs_job_tracker_id_seq');

__PACKAGE__->has_a(job_id => 'DNALC::Pipeline::NGS::Job');

__PACKAGE__->add_trigger(before_create => sub {
	#$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->add_trigger(before_update => sub {
	$_[0]->updated( POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time) );
});


1;


