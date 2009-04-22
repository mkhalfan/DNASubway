package DNALC::Pipeline::Project;

use strict;
use warnings;

use POSIX ();
use File::Path;

use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('project');
__PACKAGE__->columns(Primary => qw/project_id/);
__PACKAGE__->columns(Essential => qw/user_id name specie created/);
__PACKAGE__->sequence('project_project_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

#-----------------------------------------------------------------------------
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
#-----------------------------------------------------------------------------
sub work_dir {
	my ($self) = @_;
	return unless ref $self eq __PACKAGE__;

	my $config = DNALC::Pipeline::Config->new;
	return $config->cf('PIPELINE')->{project_dir} 
			. '/' . sprintf("%04X", $self->id);
}


sub group {
	warn "To be implemented", $/;
	return 'Monocots';
}

sub fasta_file {
	my ($self) = @_;
	
	my $ff = $self->work_dir . '/fasta.fa';
	return $ff if -e $ff;
}

#__PACKAGE__->has_a(
#    created  => 'Time::Piece',
#    inflate => sub { Time::Piece->strptime(shift, "%Y-%m-%d %H:%M:%S") },
#    deflate => sub { shift()->strftime("%Y-%m-%d %H:%M:%S") },
#);


1;
