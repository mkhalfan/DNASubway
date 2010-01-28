package DNALC::Pipeline::Workflow;

use strict;
use warnings;

use Carp;
use POSIX ();

#use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::TaskStatus ();
use DNALC::Pipeline::WorkflowHistory ();

use Data::Dumper;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('workflow');
__PACKAGE__->columns(Primary => qw/project_id task_id/);
__PACKAGE__->columns(Essential => qw/user_id status_id/);
__PACKAGE__->columns(Other => qw/duration created/);

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
	$_[0]->{duration} ||= 0.0;

	unless ($_[0]->{user_id}) {
		my $prj = DNALC::Pipeline::Project->retrieve($_[0]->{project_id});
		if ($prj) {
			$_[0]->{user_id} = $prj->user_id;
		}
	}

	if (0) {
		# archive any old entry of the same task
		my $wf = __PACKAGE__->retrieve(
						project_id => $_[0]->{project_id}, 
						   task_id => $_[0]->{task_id}
					);
		if ($wf) {
			my $args = {
					project_id => $wf->project->id,
					task_id => $wf->task->id,
					status_id => $wf->status_id,
					duration => $wf->duration,
					created => $wf->created
				};
			my $wfh = DNALC::Pipeline::WorkflowHistory->create( $args );
			$wf->delete;
		}
	}
});

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Project');
__PACKAGE__->has_a(task_id => 'DNALC::Pipeline::Task');
#__PACKAGE__->has_a(status_id => 'DNALC::Pipeline::TaskStatus');

sub project {
	my ($self) = @_;
	return $self->project_id;
}

sub task {
	my ($self) = @_;
	return $self->task_id;
}

sub status {
	my ($self) = @_;
	#return $self->status_id;
	DNALC::Pipeline::TaskStatus->retrieve($self->status_id);
}

__PACKAGE__->set_sql( get_history => q{
	SELECT task_id, status_id, duration, created 
	FROM workflow WHERE project_id = ? AND status_id != 4
	ORDER BY created
	});
__PACKAGE__->set_sql( get_history_all => q{
	SELECT task_id, status_id, duration, created 
	FROM workflow WHERE project_id = ? AND status_id != 4
	UNION
	SELECT task_id, status_id, duration, archived AS created
	FROM workflow_history WHERE project_id = ? AND status_id != 4
	ORDER BY created
	});
sub get_history {
	my ($class, $project_id, $all) = @_;
	my $sth = $all  ? __PACKAGE__->sql_get_history_all
					: __PACKAGE__->sql_get_history;
	my @args = ($project_id);
	push @args, $project_id if $all;

	$sth->execute(@args) or do { carp $!; return; };
	my @history = ();
	while (my $h = $sth->fetchrow_hashref) {
		push @history, $h;
	}
	$sth->finish;
	return \@history;
}

sub get_by_status {
	my ($class, $project, $status) = @_;
	my ($st) = DNALC::Pipeline::TaskStatus->search( name => $status);
	return unless $st;
	#my @routines = 
	$class->search(project_id => $project, status_id => $st);
}

1;

