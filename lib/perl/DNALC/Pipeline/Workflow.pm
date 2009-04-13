package DNALC::Pipeline::Workflow;

use strict;
use warnings;

use POSIX ();

#use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::TaskStatus ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('workflow');
__PACKAGE__->columns(Primary => qw/project_id task_id/);
__PACKAGE__->columns(Essential => qw/user_id status_id/);
__PACKAGE__->columns(Other => qw/duration created archived/);

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
	$_[0]->{archived} ||= 0.0;

	unless ($_[0]->{user_id}) {
		my $prj = DNALC::Pipeline::Project->retrieve($_[0]->{project_id});
		if ($prj) {
			$_[0]->{user_id} = $prj->user_id;
		}
	}

	# archive any old entry of the same task
	my $wf = __PACKAGE__->retrieve(
					project_id => $_[0]->{project_id}, 
					   task_id => $_[0]->{task_id}
				);
	if ($wf) {
		$wf->archived(1);
		$wf->update;
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

1;

__END__

package main;
use Data::Dumper;
my ($wf) = DNALC::Pipeline::Workflow->search(
                    project_id => 24,
                    task_id => 1,
					archived => 0
                );
print STDERR Dumper( $wf ), $/;
print STDERR  "ARCH: ", $wf->archived, $/;

