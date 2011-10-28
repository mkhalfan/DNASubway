package DNALC::Pipeline::NGS::Project;

use POSIX ();

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();

__PACKAGE__->table('ngs_project');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/user_id name organism common_name created/);
__PACKAGE__->columns(Other => qw/description/);
__PACKAGE__->sequence('ngs_project_id_seq');

__PACKAGE__->has_many(jobs => 'DNALC::Pipeline::NGS::Job');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->add_trigger(after_create => sub {
	my $mp = eval {
		DNALC::Pipeline::MasterProject->create({
				project_id => $_[0]->id,
				user_id => $_[0]->user_id,
				project_type => 'NGS'
			});
		};
		if ($@) {
			print STDERR  $@, $/;
		}
});

__PACKAGE__->add_trigger(before_delete => sub {
	my ($mp) = DNALC::Pipeline::MasterProject->search({
				project_id => $_[0]->{project_id},
				user_id => $_[0]->{user_id},
			});
	if ($mp) {
		$mp->delete;
	}
});

sub master_project {
	my ($mp) = DNALC::Pipeline::MasterProject->search(project_id => $_[0], project_type => 'NGS');
	return $mp;
}

1;


