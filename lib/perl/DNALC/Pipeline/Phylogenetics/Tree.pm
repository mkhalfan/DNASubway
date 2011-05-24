package DNALC::Pipeline::Phylogenetics::Tree;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();

__PACKAGE__->table('phy_tree');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id tree_name tree_type created/);
__PACKAGE__->sequence('phy_tree_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

#__PACKAGE__->add_trigger(before_create => sub {
#	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
#});

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{tree_name} ||= POSIX::strftime "tree-%Y%m%d-%H%M%S", localtime(+time);
});

1;
