package DNALC::Pipeline::TargetProject;

use POSIX ();
use File::Path;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('target_project');
__PACKAGE__->columns(Primary => qw/tpid/);
__PACKAGE__->columns(Essential => qw/name project_id type organism segment status/);
__PACKAGE__->columns(Others => qw/seq created updated/);

__PACKAGE__->sequence('target_project_tpid_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->add_trigger(before_update => sub {
    $_[0]->updated( POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time));
});

__PACKAGE__->has_many(genomes => 'DNALC::Pipeline::TargetRole');


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

