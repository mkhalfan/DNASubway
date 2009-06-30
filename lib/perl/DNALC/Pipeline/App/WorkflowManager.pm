package DNALC::Pipeline::App::WorkflowManager;

use strict;

use DNALC::Pipeline::Workflow ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::CacheMD5 ();

use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::RepeatMasker2 ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::FGenesH ();
use DNALC::Pipeline::Process::Snap ();
use DNALC::Pipeline::Process::Blast ();

use DNALC::Pipeline::Sample ();

use Digest::MD5 ();

use File::Copy;
use Carp;

{
	my %status_map = (
			"Not processed" => 1,
			"Done"          => 2,
			"Error"         => 3,
			"Processing"    => 4
		);
	my %status_id_to_name = reverse %status_map;

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
	sub get_history {
		my ($self, $all) = @_;

		my $history = DNALC::Pipeline::Workflow->get_history($self->project->project_id, $all);
		foreach my $h (@$history) {
			$h->{task_name} = $self->{task_id_to_name} -> {$h->{task_id} };
		}
		return $history;
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

		my $rc;
		my $upload_file = $self->project->work_dir . '/' . 'fasta.fa';
		
		my $sample_id = $self->project->sample;
		if ($sample_id) {
			my $sample = DNALC::Pipeline::Sample->new($sample_id);
			return unless $sample;

			$rc = $sample->copy_fasta({
					project_dir => $self->project->work_dir,
					common_name => $self->project->common_name,
					project_id => $self->project->id,
				});
			print STDERR  "Uploaded file = ", $upload_file, $/;
		} 
		else {
			unless (-f $source_file) {
				carp "Source file [$source_file] is missing\n";
			}
			
			$rc = copy $source_file, $upload_file;
			carp 'Unable to upload sequence: ', $! unless $rc;
		}

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

		if ($proj->sample) {
			my $st = $self->run_fake('repeat_masker');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'repeat_masker');
				return $st;
			}

		}

		my $rep_mask  = DNALC::Pipeline::Process::RepeatMasker->new( $proj->work_dir, $proj->clade );
		my $rep_mask2 = DNALC::Pipeline::Process::RepeatMasker2->new( $proj->work_dir, $proj->clade );
		if ($rep_mask && $rep_mask2) {

			$self->set_status('repeat_masker', 'Processing');

			#my $crc = $self->crc($rep_mask->get_options);
			# TODO
			# search for cachemd5($self->project->id, $task_name, $crc);
			# if cache_found {
			#	$self->copy_results(....);
			#	return {success => 1, gff_file => '...', elapsed => 0.01, 
			# }
			$rep_mask->run(
					input => $proj->fasta_file,
					debug => 1,
				);
			if (defined $rep_mask->{exit_status} && $rep_mask->{exit_status} == 0) {
				print STDERR  "Time 1 = ", $rep_mask->{elapsed}, $/;

				$rep_mask2->run( input => $proj->fasta_file, debug => 1);
				if (defined $rep_mask2->{exit_status} && $rep_mask2->{exit_status} == 0) {
					print STDERR "REPEAT_MASKER: success\n";
					$status->{success} = 1;
					$status->{elapsed} = $rep_mask->{elapsed} + $rep_mask2->{elapsed};
					$status->{gff_file}= $rep_mask->get_gff3_file;
					my $rc = $self->load_analysis_results($status->{gff_file}, 'repeat_masker');
					#$self->set_cache('repeat_masker', $crc);
					print STDERR  "Time 2 = ", $rep_mask2->{elapsed}, $/;
					$self->set_status('repeat_masker', 'Done', $status->{elapsed});
				}
				else {
					print STDERR "REPEAT_MASKER: fail\n";
					$self->set_status('repeat_masker', 'Error');
				}
			}
			else {
				print STDERR "REPEAT_MASKER: fail\n";
				$self->set_status('repeat_masker', 'Error');
			}
		}

		$status;
	}
	
	#-------------------------------------------------------------------------
	sub run_augustus {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;

		if ($proj->sample) {
			my $st = $self->run_fake('augustus');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'augustus');
				return $st;
			}

		}

		my $augustus = DNALC::Pipeline::Process::Augustus->new( $proj->work_dir, $proj->clade );
		if ( $augustus) {

			my $input_file = $proj->fasta_masked_nolow;
			if ($input_file) {
				print STDERR  "AUGUSTUS options = ", join('', $augustus->get_options), $/;
				$self->set_status('augustus', 'Processing');
				$augustus->run(	input => $input_file );
			}
			if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
				print STDERR "AUGUSTUS: success\n";

				$status->{success} = 1;
				$status->{elapsed} = $augustus->{elapsed};
				$status->{gff_file}= $augustus->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'augustus');
				$self->set_status('augustus', 'Done', $augustus->{elapsed});
				#my $crc = $self->crc($augustus->get_options);
				#print STDERR  "AUGUSTUS CRC = ", $crc, $/;
				#$self->set_cache('augustus', $crc);
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

		if ($proj->sample) {
			my $st = $self->run_fake('trna_scan');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'trna_scan');
				return $st;
			}

		}

		my $trna_scan = DNALC::Pipeline::Process::TRNAScan->new( $proj->work_dir );
		if ($trna_scan ) {
			my $crc = $self->crc($trna_scan->get_options);

			$self->set_status('trna_scan', 'Processing');
			$trna_scan->run(
					input => $proj->fasta_file,
				);
			if (defined $trna_scan->{exit_status} && $trna_scan->{exit_status} == 0) {
				print STDERR "TRNA_SCAN: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $trna_scan->{elapsed};
				$status->{gff_file}= $trna_scan->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'trna_scan');
				$self->set_status('trna_scan', 'Done', $trna_scan->{elapsed});
				$self->set_cache('trna_scan', $crc);
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

		if ($proj->sample) {
			my $st = $self->run_fake('fgenesh');
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'fgenesh');
				return $st;
			}
		}

		my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $proj->work_dir, $proj->clade );
		if ( $fgenesh) {

			my $input_file = $proj->fasta_masked_nolow;
			if ($input_file) {
				$self->set_status('fgenesh', 'Processing');
				$fgenesh->run(
						input => $input_file,
						debug => 0,
					);
			}
			if (defined $fgenesh->{exit_status} && $fgenesh->{exit_status} == 0) {
				print STDERR "FGENESH: success\n";

				$status->{success} = 1;
				$status->{elapsed} = $fgenesh->{elapsed};
				$status->{gff_file}= $fgenesh->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'fgenesh');
				$self->set_status('fgenesh', 'Done', $status->{elapsed});
				#my $crc = $self->crc($fgenesh->get_options);
				#$self->set_cache('fgenesh', $crc);
			}
			else {
				print STDERR "FGENESH: fail\n";
				$self->set_status('fgenesh', 'Error', $fgenesh->{elapsed});
			}
			print STDERR 'FGENESH: duration: ', $fgenesh->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------

	sub run_snap {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;

		if ($proj->sample) {
			my $st = $self->run_fake('snap');
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'snap');
				return $st;
			}
		}

		my $snap = DNALC::Pipeline::Process::Snap->new( $proj->work_dir, $proj->clade );
		if ($snap) {

			my $input_file = $proj->fasta_masked_nolow;
			if ($input_file) {
				$self->set_status('snap', 'Processing');
				$snap->run(
						input => $input_file,
					);
			}
			if (defined $snap->{exit_status} && $snap->{exit_status} == 0) {
				print STDERR "SNAP: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $snap->{elapsed};
				$status->{gff_file}= $snap->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'snap');
				$self->set_status('snap', 'Done', $snap->{elapsed});
				#$self->set_cache('snap', $self->crc($snap->get_options));
			}
			else {
				print STDERR "SNAP: fail\n";
				$self->set_status('snap', 'Error', $snap->{elapsed});
			}
			print STDERR 'SNAP: duration: ', $snap->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------
	sub run_blastn {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;

		if ($proj->sample) {
			my $st = $self->run_fake('blastn');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'blastn');
				return $st;
			}
		}

		my $blastn = DNALC::Pipeline::Process::Blast->new( $proj->work_dir, 'blastn' );
		if ($blastn) {

			my $input_file = $proj->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastn', 'Processing');
				$blastn->run( input => $input_file, debug => 1 );
			}
			if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
				print STDERR "BLASTN: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastn->{elapsed};
				$status->{gff_file}= $blastn->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastn');
				$self->set_status('blastn', 'Done', $blastn->{elapsed});
				#$self->set_cache('blastn', $self->crc($blastn->get_options));
			}
			else {
				print STDERR "BLASTN: fail\n";
				$self->set_status('blastn', 'Error');
			}
			print STDERR 'BLASTN: duration: ', $blastn->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------
	sub run_blastx {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;

		if ($proj->sample) {
			my $st = $self->run_fake('blastx');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'blastx');
				return $st;
			}
		}

		my $blastx = DNALC::Pipeline::Process::Blast->new( $proj->work_dir, 'blastx' );
		if ($blastx) {

			my $input_file = $proj->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastx', 'Processing');
				$blastx->run( input => $input_file, debug => 1 );
			}
			if (defined $blastx->{exit_status} && $blastx->{exit_status} == 0) {
				print STDERR "BLASTX: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastx->{elapsed};
				$status->{gff_file}= $blastx->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastx');
				$self->set_status('blastx', 'Done', $blastx->{elapsed});
				#$self->set_cache('blastx', $self->crc($blastx->get_options));
			}
			else {
				print STDERR "BLASTX: fail\n";
				$self->set_status('blastx', 'Error');
			}
			print STDERR 'BLASTN: duration: ', $blastx->{elapsed}, $/;
		}
		return $status;
	}

	#-------------------------------------------------------------------------
	sub run_fake {
		my ($self, $routine) = @_;

		my $status = {success => 0};

		my $proj = $self->project;
		my $sample_id = $proj->sample;
		if ($sample_id) {
			my $sample = DNALC::Pipeline::Sample->new($sample_id);
			return $status unless $sample;

			my $rc = $sample->copy_results({
						routine => $routine,
						project_id => $self->project->id,
						project_dir => $proj->work_dir,
						common_name => $proj->common_name,
					});
			if ($rc) {
				$status->{success} = 1;
				$status->{elapsed} = 1.59;
				$status->{gff_file}= $proj->get_gff3_file($routine);
				$self->set_status($routine, 'Done', $status->{elapsed});
				#copy  masked fasta files
				if ($routine eq 'repeat_masker') {
					for my $mask (qw/repeat_masker repeat_masker2/) {
						$rc = $sample->copy_fasta({
							project_dir => $self->project->work_dir,
							project_id => $self->project->id,
							common_name => $self->project->common_name,
							masker => $mask
						});
					}
				}
			}
			else {
				print STDERR  "copy_results($routine) failed...", $/;
			}
		}

		return $status;
	}
	#-------------------------------------------------------------------------
	# computes MD5 sum from the given @args list
	sub crc {
		my ($self, @args) = @_;
		my $ctx = Digest::MD5->new;
		$ctx->add(@args);
		return $ctx->hexdigest;
	}
	#-------------------------------------------------------------------------
	sub set_cache {
		my ($self, $task_name, $crc) = @_;
		
		my $c = eval {
					DNALC::Pipeline::CacheMD5->create({
						project_id => $self->project->id,
						task_name => $task_name,
						crc => $crc
					});
				};
		if ($@) {
			carp "Unable to set cache for PID=", $self->project, ', task_name = ', $task_name, $/, $@, $/;
		}

	}
	#-------------------------------------------------------------------------
	sub load_analysis_results {
		my ($self, $gff_file, $routine) = @_;

		my $username = $self->project->username;
		return unless -f $gff_file && defined $username;
		my $profile = sprintf("%s_%d", $username, $self->project->id);
		my $cmd = '/var/www/bin/load_analysis_results.pl';
		my @args = ('--username', $username, 
				'--profile', $profile,
				'--algorithm', $routine,
				'--gff', $gff_file);
		print STDERR  "\n\nLOADING DATA:\n", $cmd, " ", "@args", $/;
		print STDERR 'EXIT CODE = ', system($cmd, @args), $/;
		return 1;
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
