package DNALC::Pipeline::App::WorkflowManager;

use strict;

use DNALC::Pipeline::Workflow ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::FGenesH ();

use File::Copy;
use Carp;

{
	my %status_map = (
			"Not processed" => 1,
			"Done"          => 2,
			"Error"         => 3,
			"Running"       => 4
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
		my ($self, $task_name, $status_name, $duration) = @_;

		unless (defined $status_map{ $status_name }) {
			croak "Unknown status: ", $status_name, $/;
		}

		my $wf = DNALC::Pipeline::Workflow->retrieve(
					project_id => $self->project->id,
					task_id => $self->{task_name_to_id}->{$task_name},
				);

		if ($wf) {
			# make a history of this wf
			my $wfh = DNALC::Pipeline::WorkflowHistory->create({
						project_id => $wf->project->id,
						task_id => $wf->task->id,
						status_id => $wf->status_id,
						duration => $wf->duration,
						created => $wf->created
					});

			$wf->status_id($status_map{ $status_name });
			$wf->duration( $duration ? $duration : 0);

			$wf->update;
		}
		else {
			$wf = eval{
					DNALC::Pipeline::Workflow->create({
						project_id => $self->project->id,
						task_id => $self->{task_name_to_id}->{$task_name},
						status_id => $status_map{ $status_name },
						duration => $duration ? $duration : 0,
					});
				};
			if ( $@ ) {
				my $commit_error = $@;
				eval { $wf->dbi_rollback }; # might also die!
				die $commit_error;
			}
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
		my ($self, $source_file) = @_;

		unless (-e $source_file) {
			carp "Source file [$source_file] is missing\n";
		}
		
		my $upload_file = $self->project->work_dir . '/' . 'fasta.fa';
		my $rc = copy $source_file, $upload_file;
		print STDERR  'dont forget to remove file: ', $upload_file, $/;
		carp 'Unable to upload sequence: ', $! unless $rc;

		my $s;
		if ($rc) {
			$s = $self->set_status('upload_fasta','Done');
		}
		else {
			$s = $self->set_status('upload_fasta','Error');
		}
		return $upload_file if $rc;
	}
	#-------------------------------------------------------------------------

	sub run_repeat_masker {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;
		print STDERR "FASTA FILE = ", $proj->fasta_file, $/;;
		carp "Fasta file is missing\n" unless $proj->fasta_file;

		my $rep_mask = DNALC::Pipeline::Process::RepeatMasker->new( $proj->work_dir  );
		if ($rep_mask) {
			my $pretend = 0;
			$rep_mask->run(
					input => $proj->fasta_file,
					pretend => $pretend,
					debug => 1,
				);
			if (defined $rep_mask->{exit_status} && $rep_mask->{exit_status} == 0) {
				print STDERR "REPEAT_MASKER: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $rep_mask->{elapsed};
				$status->{gff_file}= $rep_mask->get_gff3_file;
				$self->set_status('repeat_masker', 'Done', $rep_mask->{elapsed});
			}
			else {
				print STDERR "REPEAT_MASKER: fail\n";
				$self->set_status('repeat_masker', 'Error', $rep_mask->{elapsed});
			}
			print STDERR 'RM: duration: ', $rep_mask->{elapsed}, $/ if $rep_mask->{elapsed};
		}

		$status;
	}
	
	#-------------------------------------------------------------------------
	sub run_augustus {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;
		my $augustus = DNALC::Pipeline::Process::Augustus->new( $proj->work_dir );
		if ( $augustus) {
			my $pretend = 0;
			$augustus->run(
					input => $proj->fasta_file,
					output_file => $augustus->{work_dir} . '/' . 'augustus.gff3',
					pretend => $pretend,
				);
			if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
				print STDERR "AUGUSTUS: success\n";

				$status->{success} = 1;
				$status->{elapsed} = $augustus->{elapsed};
				$status->{gff_file}= $augustus->get_gff3_file;
				$self->set_status('augustus', 'Done', $augustus->{elapsed});
			}
			else {
				print STDERR "AUGUSTUS: fail\n";
				$self->set_status('augustus', 'Error', $augustus->{elapsed});
			}
			print STDERR 'AUGUSTUS: duration: ', $augustus->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------

	sub run_trna_scan {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;

		my $trna_scan = DNALC::Pipeline::Process::TRNAScan->new( $proj->work_dir );
		if ($trna_scan ) {
			my $pretend = 0;
			$trna_scan->run(
					input => $proj->fasta_file,
					output_file => $trna_scan->{work_dir} . '/' . 'output.out',
					pretend => $pretend,
				);
			if (defined $trna_scan->{exit_status} && $trna_scan->{exit_status} == 0) {
				print STDERR "TRNA_SCAN: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $trna_scan->{elapsed};
				$status->{gff_file}= $trna_scan->get_gff3_file;
				$self->set_status('trna_scan', 'Done', $trna_scan->{elapsed});
			}
			else {
				print STDERR "TRNA_SCAN: fail\n";
				$self->set_status('trna_scan', 'Error', $trna_scan->{elapsed});
				#print $trna_scan->{cmd}, $/;
			}
			print STDERR 'TS: duration: ', $trna_scan->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------
	sub run_fgenesh {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;
		# TODO - get the specie type: Monocots|Dicots
		my $group = $proj->group;

		my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $proj->work_dir, $group );
		if ( $fgenesh) {
			my $pretend = 0;
			$fgenesh->run(
					input => $proj->fasta_file,
					pretend => $pretend,
				);
			if (defined $fgenesh->{exit_status} && $fgenesh->{exit_status} == 0) {
				print STDERR "FGENESH: success\n";

				$status->{success} = 1;
				$status->{elapsed} = $fgenesh->{elapsed};
				$status->{gff_file}= $fgenesh->get_gff3_file;
				$self->set_status('fgenesh', 'Done', $fgenesh->{elapsed});
			}
			else {
				print STDERR "FGENESH: fail\n";
				$self->set_status('fgenesh', 'Error', $fgenesh->{elapsed});
			}
			print STDERR 'FGENESH: duration: ', $fgenesh->{elapsed}, $/;
		}
		return $status;
	}
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
