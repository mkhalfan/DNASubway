package DNALC::Pipeline::TargetProject;

use POSIX ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('target_project');
__PACKAGE__->columns(Primary => qw/tpid/);
__PACKAGE__->columns(Essential => qw/name project_id organism segment status
								created updated /);
__PACKAGE__->sequence('target_project_tpid_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->add_trigger(before_update => sub {
	print STDERR  "updating....", $/;
    $_[0]->updated( POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time));
});

__PACKAGE__->has_many(roles => 'DNALC::Pipeline::TargetRole');

1;

