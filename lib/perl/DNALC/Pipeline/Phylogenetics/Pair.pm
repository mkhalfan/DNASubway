package DNALC::Pipeline::Phylogenetics::Pair;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use DNALC::Pipeline::Phylogenetics::PairSequence ();

__PACKAGE__->table('phy_pair');
__PACKAGE__->columns(Primary => qw/pair_id/);
__PACKAGE__->columns(Essential => qw/project_id alignment concensus/);
__PACKAGE__->sequence('phy_pair_pair_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');
#__PACKAGE__->has_many(paired_sequences => ['DNALC::Pipeline::Phylogenetics::PairSequence' => 'pair_id']);

#__PACKAGE__->add_trigger(before_create => sub {
#	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
#});

sub paired_sequences {
	my ($self) = @_;
	return unless ref $self eq __PACKAGE__;

	DNALC::Pipeline::Phylogenetics::PairSequence->search(
			pair_id => $self
		);
}

1;