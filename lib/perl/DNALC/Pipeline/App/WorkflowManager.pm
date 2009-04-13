package DNALC::Pipeline::App::WorkflowManager;

use strict;

use DNALC::Pipeline::Workflow ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();

use File::Copy qw/cp/;
use Carp;

{
	my %status_map = (
			"Not processed" => 1,
			"Done"          => 2,
			"Error"         => 3
		);

	sub new {
		my ($class, $project) = @_;

		my $self = {};
	
		if (defined $project && ref $project eq '' && $project =~ /^\d+$/) {
			$project = DNALC::Pipeline::Project->retrieve($project);
		}
		unless ($project) {
			return;
		}
		#init_status();
		#
		#my $wf = DNALC::Pipeline::Workflow->search(
		#		project_id => $project,
		#		user_id	=> $user_id,
		#		archived => 0
		#	);
		#unless ($wf) {
		#	init_workflow();
		#}

		$self->{project} = $project;

		bless $self, __PACKAGE__;
		$self->_init;

		$self;
	}

	sub _init {
		my ($self) = @_;

		my %task_id_to_name = ();
		my %task_name_to_id = ();
		my $tasks = DNALC::Pipeline::Task->retrieve_all;
		while (my $task = $tasks->next) {
			next unless $task->enabled;
			$task_id_to_name{ $task->id } = $task->name;
			$task_name_to_id{ $task->name } = $task->id;
		}
		$self->{task_id_to_name} = \%task_id_to_name;
		$self->{task_name_to_id} = \%task_name_to_id;
	}

	#-------------------------------------------------------------------------
	sub project {
		my ($self) = @_;
		return $self->{project};
	}

	#-------------------------------------------------------------------------
	sub set_status {
		my ($self, $task_name, $status_name) = @_;

		unless (defined $status_map{ $status_name }) {
			croak "Unknown status: ", $status_name, $/;
		}

		my $wf = eval{
					DNALC::Pipeline::Workflow->create({
						project_id => $self->project->id,
						task_id => $self->{task_name_to_id}->{$task_name},
						status_id => $status_map{ $status_name }
					});
				};
		if ( $@ ) {
			my $commit_error = $@;
			eval { $wf->dbi_rollback }; # might also die!
			die $commit_error;
		}
		$wf->dbi_commit;
		$wf->status;
	}

	sub get_status {
		my ($self, $task_name) = @_;
		#print STDERR  "11. getting status for task_id = ", $self->{task_name_to_id}->{$task_name}, $/;
		my ($wf) = DNALC::Pipeline::Workflow->search(
					project_id => $self->project->id,
					task_id => $self->{task_name_to_id}->{$task_name},
					archived => 0
				);

		unless ($wf) {
			return DNALC::Pipeline::TaskStatus->retrieve( $status_map{'Not processed'} );
		}
		$wf->status;
	}
	#-------------------------------------------------------------------------

	sub select_sequence {
		my ($self, $source) = @_;
		# source is a hash may be one of:
		#	genebank- genebank accession number
		#	- upload fasta file
		#	- from DNALC repository
	}

	sub upload_sequence {
		my ($self, $io_h) = @_;
		
		# FIXME - io_h should be the upload handler 

		my $upload_file = $self->project->work_dir . '/' . 'fasta.fa';
		#my $rc = DNALC::Pipeline::App::Utils->upload($r, $upload_file);
		my $rc = cp $io_h, $upload_file;
		carp 'Unable to upload sequence: ', $! unless $rc;

		my $s;
		if ($rc) {
			$s = $self->set_status('upload_fasta','Done');
		}
		else {
			$s = $self->set_status('upload_fasta','Error');
		}
		use Data::Dumper;
		print STDERR "\nAfter upload: ", Dumper( $s), $/;
		return $upload_file if $rc;
	}
	#-------------------------------------------------------------------------
}

=head1 TODO

=item * $class->new($project_id, $user_id)

=item * $self->upload_sequence

Initializes the project if needed, sets the default status for the project(Not processed)
We actually won't have nothing stored in the DB in this case.

=item * $self->select_sequence

Sets the sequence for the project (from DNALC sources)

=item * $self->upload_game

Uploads a game file

=item * $self->set_status($project, $task, $status)

Sets the status for a task/project

=item * $self->get_status($project, $task)

Return the status for a task/project


=cut



1;
