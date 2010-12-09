package DNALC::Pipeline::Phylogenetics::Sample;

#use Carp;
use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_sample');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/name name type name dir description 
		/);
__PACKAGE__->columns(Other => qw/active created/);

__PACKAGE__->sequence('phy_sample_id_seq');

sub files {
	my ($self) = @_;
	my $dir = $self->dir;
	return <$dir/*> if -d $dir;
}

1;

__END__
package main;
my $s = DNALC::Pipeline::Phylogenetics::Sample->retrieve(1);
print $s, ' ', $s->dir, $/;
print join "\n", $s->files, $/;
