package DNALC::Pipeline::Project;

use strict;
use warnings;

use POSIX ();
use File::Path;

use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('project');
__PACKAGE__->columns(Primary => qw/project_id/);
__PACKAGE__->columns(Essential => qw/user_id name organism common_name 
							sample created/);
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

#-------------------------------
# TODO: Move into ProjectManager.pm

sub get_gff3_file {
	my ($self, $routine) = @_;
	
	$routine = uc $routine;
	my $dir = $self->work_dir . '/' . $routine;
	return unless -d $dir;

	my $config = DNALC::Pipeline::Config->new;
	my $file = $dir . '/' . $config->cf($routine)->{gff3_file};
	#print STDERR  "GFF3 for {$routine} = ", $file, $/;
	return $file if -f $file;
}

sub get_available_gff3_files {
	my ($self) = @_;

	my @files = ();
	my $config = DNALC::Pipeline::Config->new;
	my $routines = $config->cf('PIPELINE')->{enabled_routines} || [];

	for my $routine (@$routines) {
		my $f = $self->get_gff3_file($routine);
		#print STDERR  $routine, "->", $f, $/;
		push @files, $f if defined ($f) &&  -f $f;
	}
	return \@files;
}

1;
