package DNALC::Pipeline::Phylogenetics::Alignment;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();

__PACKAGE__->table('phy_alignment');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id aln_name aln_type file created/);
__PACKAGE__->sequence('phy_alignment_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

__PACKAGE__->add_trigger(before_create => sub {
	my $tmpl = sprintf("a%s-%%y%%m%%d.%%H%%M%%S", $_[0]->{tree_type});
	$_[0]->{aln_name} ||= POSIX::strftime $tmpl, localtime(+time);
});

1;
