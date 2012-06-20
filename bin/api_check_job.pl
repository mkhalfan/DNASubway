#!/usr/bin/perl

use strict;

use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::NGS::Job ();
use DNALC::Pipeline::NGS::JobTrack ();
use DNALC::Pipeline::NGS::DataSource ();
use DNALC::Pipeline::NGS::DataFile ();
use DNALC::Pipeline::User ();
use iPlant::FoundationalAPI ();
use File::Basename;

use DNALC::Pipeline::App::NGS::ProjectManager ();

use Data::Dumper;

my $debug = shift;

#----------------------

my $jts = DNALC::Pipeline::NGS::JobTrack->search(tracker_status => '');

while (my $jt = $jts->next) {
	next unless $jt->token;

	my $job = $jt->job_id;
	my $user = DNALC::Pipeline::User->retrieve($jt->user_id);
	print $jt, " ", $job, " ", $user->username, $/ if $debug;
	my $fapi = iPlant::FoundationalAPI->new( user => $user->username, token => $jt->token );
	#$fapi->debug($debug);

	if ($fapi->auth) { # if successfully authenticated 
		my $pm = DNALC::Pipeline::App::NGS::ProjectManager->new({project => $job->project_id});
		$pm->api_instance($fapi);

		my $job_ep = $fapi->job;
		my $api_job = $job_ep->job_details($jt->api_job_id);
		next unless ref($api_job);

		# ths mostly sets startTime, endTime
		$job->set_params($api_job);

		#print STDERR Dumper( $api_job), $/;
		my $api_status = $api_job->{status};

		print STDERR  $api_job->{status}, ' - ', $api_job->{message} || '', $/ if $debug;
		$jt->api_status($api_status);

		if ($api_status =~ /(?:FINISHED|KILLED|FAILED|STOPPED|ARCHIVING_FINISHED|ARCHIVING_FAILED)/) {
			# the job hit a terminal stage: it will not change it's status

			$jt->token('');
			if ($api_status =~ /(?:FINISHED|ARCHIVING_FINISHED)/) {
				$jt->tracker_status('success');
				$job->status_id(2); # done

				my $task = $job->task_id->name;

 				print STDERR  '$task = ', $task, $/ if $debug;

				my $job_name = $job->attrs->{name};
				my $app_conf = DNALC::Pipeline::Config->new->cf(uc $task);

				my $io_ep = $fapi->io;
				my $all_files    = $io_ep->ls($api_job->{archivePath});
				my $out_dir_re   = $app_conf->{_output_dir};
				my $out_files_re = $app_conf->{_output_files};
				my ($data_dir)   = $out_dir_re ? grep {$_->path =~ /$out_dir_re/} @$all_files : @$all_files;
				print STDERR 'data_dir: ', $data_dir->path, $/ if ($debug && $data_dir);


				#print STDERR  'data_dir: ', $api_job->{archivePath}, $/;

				my @data_files = grep { $_->path =~ /$out_files_re/ } @{$io_ep->ls($data_dir->path)}
					if $data_dir;

				print STDERR 'data_files: ', "@data_files", $/ if $debug;

				#
				# mark output file are shared so $DNALCADMIN user be able to read them
				my $ngs_cfg = DNALC::Pipeline::Config->new->cf('NGS');
				for (@data_files) {
					print STDERR  '++ sharing file ', $_->name, $/ if $debug;
					my $st = $io_ep->share($_->path, $ngs_cfg->{admin_user}, canRead => 1);
					#print STDERR '++ shared: ', Dumper( $st ), $/;
				}

				my $src_id;
				
				if ($app_conf->{_on_success} && $pm->can('task_' . $app_conf->{_on_success})) {
					my $output_handler = 'task_' . $app_conf->{_on_success};
					print STDERR  ' ++ output_handler: ', $output_handler, $/ if $debug;
					$pm->$output_handler($job, \@data_files);
				}
				else {
					print STDERR  "No [on_success] handler defined for [", $app_conf->{id},"]\n" if $debug;
					if (@data_files) {
						#print STDERR Dumper( \@data_files ), $/ if $debug;
						$src_id = DNALC::Pipeline::NGS::DataSource->create({
									project_id => $job->project_id,
									name => 'Output from ' . $task,
									note => $job_name || '',
								});
						if ($!) {
							print STDERR 'Can\'t add source: ', $! , $/;
						}
					}

					if ($src_id) {
						my $counter = 0;
						my $base_name = '';
						my @job_input_files = $job->input_files;
						if (@job_input_files == 1) {
							$base_name = $job_input_files[0]->file->file_name;
							$base_name =~ s/\.(.*?)$//;
						}

						for my $df (@data_files)  {
							my ($file_type) = $df->path =~ /\.(.*?)$/;
							my $fname = $df->name;

							# keep the same basename for the file
							if ($app_conf->{_propagate_input_file_name}) {
								if ($base_name) {
									$fname = $base_name . sprintf("%s.%s", $counter > 1 ? $counter : '', $fname =~ /\.(.*?)$/);
								}
							}

							print STDERR  'output file: ', $fname, $/ if $debug;
							my $data_file = DNALC::Pipeline::NGS::DataFile->create({
									project_id => $job->project_id,
									source_id => $src_id,
									file_name => $fname,
									file_path => $df->path,
									file_type => $file_type || '',
								});
							$counter++;
						}
					} # end if($src_id)
				}
			}
			else { # KILLED|FAILED|STOPPED|ARCHIVING_FAILED
				$jt->tracker_status('failed' . ' - ' . $api_job->{message});
				$job->status_id(3); # error
			}

#
			$job->update;
		}
	}
	else {
		# token expired
		# we'll handle this in a different way
		$jt->token('');
	}

#
	$jt->update;

#	last;
}

exit 0;


