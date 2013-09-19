package DNALC::Pipeline::Phylogenetics::Tree;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();

__PACKAGE__->table('phy_tree');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id tree_name tree_type alignment created/);
__PACKAGE__->sequence('phy_tree_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

__PACKAGE__->add_trigger(before_create => sub {
	my $tmpl = sprintf("t%s-%%y%%m%%d.%%H%%M%%S", $_[0]->{tree_type});
	$_[0]->{tree_name} ||= POSIX::strftime $tmpl, localtime(+time);
});

1;
