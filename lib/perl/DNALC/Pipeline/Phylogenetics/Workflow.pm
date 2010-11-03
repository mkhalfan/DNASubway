package DNALC::Pipeline::Phylogenetics::Workflow;

use Carp;
use POSIX ();

use DNALC::Pipeline::Phylogenetics::Project ();
use DNALC::Pipeline::TaskStatus ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_workflow');
__PACKAGE__->columns(Primary => qw/project_id task_id/);
__PACKAGE__->columns(Essential => qw/user_id status_id/);
__PACKAGE__->columns(Other => qw/duration created/);

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
	$_[0]->{duration} ||= 0.0;

	unless ($_[0]->{user_id}) {
		my $prj = DNALC::Pipeline::Phylogenetics::Project->retrieve($_[0]->{project_id});
		if ($prj) {
			$_[0]->{user_id} = $prj->user_id;
		}
	}
});

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');
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
