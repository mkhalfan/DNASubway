package DNALC::Pipeline::Phylogenetics::PairSequence;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();

__PACKAGE__->table('phy_pair_sequence');
__PACKAGE__->columns(Primary => qw/project_id seq_id/);
__PACKAGE__->columns(Essential => qw/pair_id strand/);

#__PACKAGE__->has_a(pair_id => 'DNALC::Pipeline::Phylogenetics::Pair');
__PACKAGE__->has_a(seq_id => 'DNALC::Pipeline::Phylogenetics::DataSequence');

#__PACKAGE__->add_trigger(before_create => sub {
#	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
#});

sub seq {
	shift->seq_id;
}

1;
