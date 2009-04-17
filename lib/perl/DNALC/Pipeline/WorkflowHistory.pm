package DNALC::Pipeline::WorkflowHistory;

use strict;
use warnings;

use POSIX ();

#use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::TaskStatus ();

use Data::Dumper;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('workflow_history');
__PACKAGE__->columns(Primary => qw/id /);
__PACKAGE__->columns(Essential => qw/project_id task_id status_id/);
__PACKAGE__->columns(Other => qw/duration created archived/);

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{archived} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
	$_[0]->{duration} ||= 0;
});

#__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Project');
#__PACKAGE__->has_a(task_id => 'DNALC::Pipeline::Task');
#__PACKAGE__->has_a(status_id => 'DNALC::Pipeline::TaskStatus');


1;


