package DNALC::Pipeline::App::WorkflowManager;

use strict;

use DNALC::Pipeline::Workflow ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::CacheMD5 ();
use DNALC::Pipeline::CacheMemcached ();

use DNALC::Pipeline::App::ProjectManager ();
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
			"not-processed" => 1,
			"done"          => 2,
			"error"         => 3,
			"processing"    => 4
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

		$self->{_mc} = DNALC::Pipeline::CacheMemcached->new;
		$self->{project} = $project;
		$self->{pmanager} = DNALC::Pipeline::App::ProjectManager->new($project);

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
		$self->{project};
	}

	sub pmanager {
		my ($self) = @_;
		$self->{pmanager};
	}

	#-------------------------------------------------------------------------
	sub set_status {
		my ($self, $task_name, $status_name, $duration) = @_;

		unless (defined $status_map{ $status_name }) {
			croak "Unknown status: ", $status_name, $/;
		}

		my $mc_key = "status-$task_name-" . $self->project->id;
		$self->{_mc}->set($mc_key, lc( $status_name ));

		my $wf = DNALC::Pipeline::Workflow->retrieve(
					project_id => $self->project->id,
					task_id => $self->{task_name_to_id}->{$task_name},
				);

		if ($wf) {
			# make a history of this wf
			my $wfh = DNALC::Pipeline::WorkflowHistory->create({
						project_id => $self->project->id,
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
		#$wf->dbi_commit;
		if ($status_name ne "processing") {
			$self->log("Setting status for routine [$task_name] to [$status_name] " 
					. ($duration ? "($duration sec)." : '')
				);
		}

		$wf->status;
	}

	sub get_status {
		my ($self, $task_name) = @_;

		my $mc_key = "status-$task_name-" . $self->project->id;
		my $mc_status = $self->{_mc}->get($mc_key);
		if ($mc_status) {
			print STDERR  " \@\@ 10. MC status for task_id = ", $task_name, ' == ', $mc_status, $/;
			return DNALC::Pipeline::TaskStatus->retrieve( $status_map{$mc_status} );
		}
		
		my ($wf) = DNALC::Pipeline::Workflow->search(
					project_id => $self->project->id,
					task_id => $self->{task_name_to_id}->{$task_name},
				);

		unless ($wf) {
			return DNALC::Pipeline::TaskStatus->retrieve( $status_map{'not-processed'} );
		}
		#print STDERR  "11. getting status for task_id = ", $task_name, ' == ', $wf->status->name, $/;
		$wf->status;
	}
	#-------------------------------------------------------------------------
	# returns a list of the done routines
	sub get_done {
		my ($self) = @_;
		map { 
			$_->task->name 
		} DNALC::Pipeline::Workflow->get_by_status($self->project, 'done');
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
		my $upload_file = $self->pmanager->work_dir . '/' . 'fasta.fa';
		
		my $sample_id = $self->project->sample;
		if ($sample_id) {
			my $sample = DNALC::Pipeline::Sample->new($sample_id);
			return unless $sample;

			$rc = $sample->copy_fasta({
					project_dir => $self->pmanager->work_dir,
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
			$s = $self->set_status('upload_fasta','done');
		}
		else {
			$s = $self->set_status('upload_fasta','error');
		}
		return $upload_file if $rc;
	}
	#-------------------------------------------------------------------------

	sub run_repeat_masker {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('repeat_masker');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'repeat_masker');
				return $st;
			}

		}

		my $rep_mask  = DNALC::Pipeline::Process::RepeatMasker->new( $pm->work_dir, $proj->clade );
		my $rep_mask2 = DNALC::Pipeline::Process::RepeatMasker2->new( $pm->work_dir, $proj->clade );
		if ($rep_mask && $rep_mask2) {

			$self->set_status('repeat_masker', 'processing');

			#my $crc = $self->crc($rep_mask->get_options);
			# TODO
			# search for cachemd5($proj->id, $task_name, $crc);
			# if cache_found {
			#	$self->copy_results(....);
			#	return {success => 1, gff_file => '...', elapsed => 0.01, 
			# }
			$rep_mask->run(
					input => $pm->fasta_file,
					debug => 1,
				);
			if (defined $rep_mask->{exit_status} && $rep_mask->{exit_status} == 0) {
				print STDERR  "Time 1 = ", $rep_mask->{elapsed}, $/;

				$rep_mask2->run( input => $pm->fasta_file, debug => 1);
				if (defined $rep_mask2->{exit_status} && $rep_mask2->{exit_status} == 0) {
					print STDERR "REPEAT_MASKER: success\n";
					$status->{success} = 1;
					$status->{elapsed} = $rep_mask->{elapsed} + $rep_mask2->{elapsed};
					$status->{gff_file}= $rep_mask->get_gff3_file;
					my $rc = $self->load_analysis_results($status->{gff_file}, 'repeat_masker');
					#$self->set_cache('repeat_masker', $crc);
					print STDERR  "Time 2 = ", $rep_mask2->{elapsed}, $/;
					$self->set_status('repeat_masker', 'done', $status->{elapsed});
				}
				else {
					print STDERR "REPEAT_MASKER: fail\n";
					$self->set_status('repeat_masker', 'error');
				}
			}
			else {
				print STDERR "REPEAT_MASKER: fail\n";
				$self->set_status('repeat_masker', 'error');
			}
		}

		$status;
	}
	
	#-------------------------------------------------------------------------
	sub run_augustus {
		my ($self) = @_;
		
		my $status = { success => 0 };
	
		my $proj = $self->project;
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('augustus');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'augustus');
				return $st;
			}

		}

		my $augustus = DNALC::Pipeline::Process::Augustus->new( $pm->work_dir, $proj->clade );
		if ( $augustus) {

			my $input_file = $pm->fasta_masked_nolow;
			if ($input_file) {
				print STDERR  "AUGUSTUS options = ", join('', $augustus->get_options), $/;
				$self->set_status('augustus', 'processing');
				$augustus->run(	input => $input_file );
			}
			if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
				print STDERR "AUGUSTUS: success\n";

				$status->{success} = 1;
				$status->{elapsed} = $augustus->{elapsed};
				$status->{gff_file}= $augustus->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'augustus');
				$self->set_status('augustus', 'done', $augustus->{elapsed});
				#my $crc = $self->crc($augustus->get_options);
				#print STDERR  "AUGUSTUS CRC = ", $crc, $/;
				#$self->set_cache('augustus', $crc);
			}
			else {
				print STDERR "AUGUSTUS: fail\n";
				$self->set_status('augustus', 'error', $augustus->{elapsed});
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
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('trna_scan');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'trna_scan');
				return $st;
			}

		}

		my $trna_scan = DNALC::Pipeline::Process::TRNAScan->new( $pm->work_dir );
		if ($trna_scan ) {
			my $crc = $self->crc($trna_scan->get_options);

			$self->set_status('trna_scan', 'processing');
			$trna_scan->run(
					input => $pm->fasta_file,
				);
			if (defined $trna_scan->{exit_status} && $trna_scan->{exit_status} == 0) {
				print STDERR "TRNA_SCAN: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $trna_scan->{elapsed};
				$status->{gff_file}= $trna_scan->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'trna_scan');
				$self->set_status('trna_scan', 'done', $trna_scan->{elapsed});
				$self->set_cache('trna_scan', $crc);
			}
			else {
				print STDERR "TRNA_SCAN: fail\n";
				$self->set_status('trna_scan', 'error', $trna_scan->{elapsed});
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
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('fgenesh');
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'fgenesh');
				return $st;
			}
		}

		my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $pm->work_dir, $proj->clade );
		if ( $fgenesh) {

			my $input_file = $pm->fasta_masked_nolow;
			if ($input_file) {
				$self->set_status('fgenesh', 'processing');
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
				$self->set_status('fgenesh', 'done', $status->{elapsed});
				#my $crc = $self->crc($fgenesh->get_options);
				#$self->set_cache('fgenesh', $crc);
			}
			else {
				print STDERR "FGENESH: fail\n";
				$self->set_status('fgenesh', 'error', $fgenesh->{elapsed});
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
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('snap');
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'snap');
				return $st;
			}
		}

		my $snap = DNALC::Pipeline::Process::Snap->new( $pm->work_dir, $proj->clade );
		if ($snap) {

			my $input_file = $pm->fasta_masked_nolow;
			if ($input_file) {
				$self->set_status('snap', 'processing');
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
				$self->set_status('snap', 'done', $snap->{elapsed});
				#$self->set_cache('snap', $self->crc($snap->get_options));
			}
			else {
				print STDERR "SNAP: fail\n";
				$self->set_status('snap', 'error', $snap->{elapsed});
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
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('blastn');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'blastn');
				return $st;
			}
		}

		my $blastn = DNALC::Pipeline::Process::Blast->new( $pm->work_dir, 'blastn' );
		if ($blastn) {

			my $input_file = $pm->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastn', 'processing');
				$blastn->run( input => $input_file, debug => 1 );
			}
			if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
				print STDERR "BLASTN: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastn->{elapsed};
				$status->{gff_file}= $blastn->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastn');
				$self->set_status('blastn', 'done', $blastn->{elapsed});
				#$self->set_cache('blastn', $self->crc($blastn->get_options));
			}
			else {
				print STDERR "BLASTN: fail\n";
				$self->set_status('blastn', 'error');
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
		my $pm   = $self->pmanager;

		if ($proj->sample) {
			my $st = $self->run_fake('blastx');
			#return $st if $st->{success};
			if ($st->{success}) {
				$self->load_analysis_results($st->{gff_file}, 'blastx');
				return $st;
			}
		}

		my $blastx = DNALC::Pipeline::Process::Blast->new( $pm->work_dir, 'blastx' );
		if ($blastx) {

			my $input_file = $pm->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastx', 'processing');
				$blastx->run( input => $input_file, debug => 1 );
			}
			if (defined $blastx->{exit_status} && $blastx->{exit_status} == 0) {
				print STDERR "BLASTX: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastx->{elapsed};
				$status->{gff_file}= $blastx->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastx');
				$self->set_status('blastx', 'done', $blastx->{elapsed});
				#$self->set_cache('blastx', $self->crc($blastx->get_options));
			}
			else {
				print STDERR "BLASTX: fail\n";
				$self->set_status('blastx', 'error');
			}
			print STDERR 'BLASTX: duration: ', $blastx->{elapsed}, $/;
		}
		return $status;
	}

	#-------------------------------------------------------------------------
	sub run_blastn_user {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;
		my $pm   = $self->pmanager;

		# no deed to check for canned results in this case

		my $blastn = DNALC::Pipeline::Process::Blast->new( $pm->work_dir, 'blastn_user' );
		if ($blastn) {

			my $input_file = $pm->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastn_user', 'processing');
				$blastn->run( input => $input_file, debug => 1 );
			}
			if (defined $blastn->{exit_status} && $blastn->{exit_status} == 0) {
				print STDERR "BLASTN_USER: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastn->{elapsed};
				$status->{gff_file}= $blastn->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastn_user');
				$self->set_status('blastn_user', 'done', $blastn->{elapsed});
				#$self->set_cache('blastn', $self->crc($blastn->get_options));
			}
			else {
				print STDERR "BLASTN_USER:: fail\n";
				$self->set_status('blastn_user', 'error');
			}
			print STDERR 'BLASTN_USER: duration: ', $blastn->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------
	sub run_blastx_user {

		my ($self) = @_;
		
		my $status = { success => 0 };	
		my $proj = $self->project;
		my $pm   = $self->pmanager;

		my $blastx = DNALC::Pipeline::Process::Blast->new( $pm->work_dir, 'blastx_user' );
		if ($blastx) {
			my $input_file = $pm->fasta_masked_xsmall;
			if ($input_file) {
				$self->set_status('blastx_user', 'processing');
				$blastx->run( input => $input_file, debug => 1 );
			}
			if (defined $blastx->{exit_status} && $blastx->{exit_status} == 0) {
				print STDERR "BLASTX_USER: success\n";
				$status->{success} = 1;
				$status->{elapsed} = $blastx->{elapsed};
				$status->{gff_file}= $blastx->get_gff3_file;
				my $rc = $self->load_analysis_results($status->{gff_file}, 'blastx_user');
				$self->set_status('blastx_user', 'done', $blastx->{elapsed});
				#$self->set_cache('blastx_user', $self->crc($blastx->get_options));
			}
			else {
				print STDERR "BLASTX_USER:: fail\n";
				$self->set_status('blastx_user', 'error');
			}
			print STDERR 'BLASTX_USER: duration: ', $blastx->{elapsed}, $/;
		}
		return $status;
	}
	#-------------------------------------------------------------------------
	sub run_fake {
		my ($self, $routine) = @_;

		my $status = {success => 0};

		my $proj = $self->project;
		my $pm   = $self->pmanager;

		my $sample = DNALC::Pipeline::Sample->new($proj->sample);
		#print STDERR 'FAKE:....', Dumper( $sample ), $/;
		return $status unless $sample;

		my $rc = $sample->copy_results({
					routine => $routine,
					project_id => $proj->id,
					project_dir => $pm->work_dir,
					common_name => $proj->common_name,
				});
		if ($rc) {
			$status->{success} = 1;
			$status->{elapsed} = 1.59;
			$status->{gff_file}= $pm->get_gff3_file($routine);
			$self->set_status($routine, 'done', $status->{elapsed});
			#copy  masked fasta files
			if ($routine eq 'repeat_masker') {
				for my $mask (qw/repeat_masker repeat_masker2/) {
					$rc = $sample->copy_fasta({
						project_dir => $proj->work_dir,
						project_id => $proj->id,
						common_name => $proj->common_name,
						masker => $mask
					});
				}
			}
		}
		else {
			print STDERR  "copy_results($routine) failed...", $/;
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

		my $username = $self->pmanager->username;
		return unless -f $gff_file && defined $username;
		if (-s $gff_file < 20) {
			print STDERR  "SKIPPING FILE (too small): ", $gff_file, $/;
			return;
		}
		#my $profile = sprintf("%s_%d", $username, $self->project->id);
		my $profile = $self->pmanager->chado_user_profile;
		my $config = $self->pmanager->config;

		my $cmd = $config->{EXE_PATH} . '/load_analysis_results.pl';
		my @args = ('--username', $username, 
				'--profile', $profile,
				'--algorithm', $routine,
				'--gff', $gff_file);
		print STDERR  "\n\nLOADING DATA:\n", $cmd, " ", "@args", $/;
		print STDERR  '-' x 20, $/;
		system($cmd, @args);
		return 1;
	}
	#-------------------------------------------------------------------------
	sub count_runs {
		my ($self, %args) = @_;

		my ($user_id, $task_id);

		if (defined $args{user_id} && $args{user_id}) {
			$user_id = $args{user_id};
		}
		if (defined $args{task_id} && $args{task_id}) {
			$task_id = $args{task_id};
		}
		if (defined $args{task} && $args{task}) {
			$task_id = $self->{task_name_to_id}->{ $args{task} };
		}

		if (! $user_id && $self->project) {
			$user_id = $self->project->user_id;
		}
		if (! $user_id || !$task_id) {
			Carp::carp "WFM::count_runs: invalid args: ", Dumper(\%args);
			return;
		}
		DNALC::Pipeline::Workflow->count_by_user_task_interval($user_id, $task_id);
	}
	#-------------------------------------------------------------------------
	sub log {
		my ($self, $message, %args) = @_;
		$self->{pmanager}->log($message, %args);
	}
	#-------------------------------------------------------------------------
}

=head1 TODO

=item * $class->new($project_id, $user_id)

=item * $self->upload_sequence

Initializes the project if needed, sets the default status for the project(not-processed)
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
