package DNALC::Pipeline::TargetProject;

use POSIX ();
use File::Path;

use base qw(DNALC::Pipeline::DBI);
use DNALC::Pipeline::MasterProject ();
#use Data::Dumper;

__PACKAGE__->table('target_project');
__PACKAGE__->columns(Primary => qw/tpid/);
__PACKAGE__->columns(Essential => qw/user_id name project_id type organism segment 
									gp_name class_name function_name status/);
__PACKAGE__->columns(Others => qw/seq created updated/);

__PACKAGE__->sequence('target_project_tpid_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->add_trigger(before_update => sub {
    $_[0]->updated( POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time));
});

__PACKAGE__->add_trigger(after_create => sub {
	my $mp = eval {
		DNALC::Pipeline::MasterProject->create({
				user_id => $_[0]->user_id,
				project_id => $_[0]->id,
				project_type => 'target'
			});
	};
	if ($@) {
		print STDERR  $@, $/;
	}
});

__PACKAGE__->add_trigger(before_delete => sub {
	my ($mp) = DNALC::Pipeline::MasterProject->search({
				project_id => $_[0]->{tpid},
				user_id => $_[0]->{user_id},
			});
	if ($mp) {
		$mp->delete;
	}
	else {
		print STDERR  "MasterP for project ", $_[0]->{project_id}, " not found.", $/;
	}
});

__PACKAGE__->has_many(genomes => 'DNALC::Pipeline::TargetRole');

#---------------------------------------------------

sub retrieve_all {

	__PACKAGE__->retrieve_from_sql ( q{
			1 = 1
			ORDER BY tpid asc
		});
}

#-----------------------------------------------------------------------------

sub common_name {

	return $_[0]->segment;
}

sub work_dir {
	my ($self) = @_;

	my $cf = DNALC::Pipeline::Config->new->cf('TARGET');

	return sprintf ("%s/%04X", $cf->{PROJECTS_DIR}, $self->id);
}

sub create_work_dir {
	my ($self) = @_;
	my $path = $self->work_dir;
	return unless $path;
	eval { mkpath($path) };
	if ($@) {
		print STDERR "Couldn't create $path: $@", $/;
		return;
	}
	return 1;
}

1;

