package DNALC::Pipeline::Phylogenetics::Pair;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use DNALC::Pipeline::Phylogenetics::PairSequence ();

__PACKAGE__->table('phy_pair');
__PACKAGE__->columns(Primary => qw/pair_id/);
__PACKAGE__->columns(Essential => qw/project_id alignment consensus name f_trim r_trim/);
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
			pair_id => $self, { order_by => 'seq_id' }
		);
}

sub formatted_alignment {
	my ($self) = @_;

# 	if (0 && length($merged_seq) != $algn_length) {
# 			#print STDERR  "Not equal...", $/;
# 			my @strings = map {lc $data->{$_}} keys %$data;
# 			#print STDERR Dumper( \@strings), $/;
	# 
# 			for (my $i = 0; $i < $algn_length; $i++) {
# 				my ($n1, $n2) = (substr($strings[0], $i, 1),  substr($strings[1], $i, 1));
# 				print $n1 eq $n2
# 					? ' ' 
# 					: "$n1$n2" =~ /[n-]{2}/ 
# 						? '[' . substr($merged_seq, $i, 1) . ']'
# 						: 'x';
# 			}
# 			print STDERR $/;
# 	}
	return $self->alignment;
}

1;
