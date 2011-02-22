package DNALC::Pipeline::Phylogenetics::Project;

use POSIX ();

use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();

__PACKAGE__->table('phy_project');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/user_id name type  sample created/);
__PACKAGE__->columns(Other => qw/has_tools description/);

__PACKAGE__->sequence('phy_project_id_seq');


__PACKAGE__->has_many(datasources => 'DNALC::Pipeline::Phylogenetics::DataSource');


__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


__PACKAGE__->add_trigger(after_create => sub {
	my $mp = eval {
		DNALC::Pipeline::MasterProject->create({
				project_id => $_[0]->id,
				user_id => $_[0]->user_id,
				project_type => 'phylogenetics'
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
	#else {
	#	print STDERR  "MasterP for project ", $_[0]->{project_id}, " not found.", $/;
	#}
});


sub master_project {
	my ($mp) = DNALC::Pipeline::MasterProject->search(project_id => $_[0]);
	return $mp;
}

1;
