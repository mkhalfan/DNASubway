#!/usr/bin/perl

use strict;

use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::NGS::Job ();
use DNALC::Pipeline::NGS::JobTrack ();
use DNALC::Pipeline::NGS::DataSource ();
use DNALC::Pipeline::NGS::JobOutputFile ();
use DNALC::Pipeline::NGS::DataFile ();
use DNALC::Pipeline::User ();
use iPlant::FoundationalAPI ();
use File::Basename;

use DNALC::Pipeline::App::NGS::ProjectManager ();
use DNALC::Pipeline::CacheMemcached ();

use Data::Dumper;

my $debug = shift;

#----------------------

my $mc = DNALC::Pipeline::CacheMemcached->new;
my $jts = DNALC::Pipeline::NGS::JobTrack->search(tracker_status => '');

while (my $jt = $jts->next) {
	next unless $jt->token;

	my $job = $jt->job_id;
	my $user = DNALC::Pipeline::User->retrieve($jt->user_id);
	print $jt, " ", $job, " ", $user->username, " ", $job->task->name, $/ if $debug;

	my $mc_key = 'tracked-job-' . $job->id;

	# see if we're already working on this job (maybe transfer its files..)
	if ($mc->get($mc_key)) {
		print STDERR  "Already working on this job", $/ if $debug;
		next;
	}

	# set the cache flag 
	$mc->set($mc_key, 1, 20 * 60); # set this for 20 minutes

	my $fapi = iPlant::FoundationalAPI->new( user => $user->username, token => $jt->token );
	#$fapi->debug($debug);

	if ($fapi->auth) { # if successfully authenticated 
		my $pm = DNALC::Pipeline::App::NGS::ProjectManager->new({project => $job->project_id, debug => $debug});
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

		# the job hits a terminal stage: it will no longer change it's status
		if ($api_status =~ /(?:FINISHED|KILLED|FAILED|STOPPED|ARCHIVING_FINISHED|ARCHIVING_FAILED)/) {

			$jt->token('');
			if ($api_status =~ /(?:FINISHED|ARCHIVING_FINISHED)/) {
				$jt->tracker_status('success');
				$job->status_id(2); # done

				my $task = $job->task_id->name;

 				print STDERR  'task = ', $task, $/ if $debug;

				my $job_name = $job->attrs->{name};
				my $app_conf = DNALC::Pipeline::Config->new->cf(uc $task);

				my $io_ep = $fapi->io;
				my $root_files   = $io_ep->ls($api_job->{archivePath});
				my $out_files_re = $app_conf->{_output_files};
				my $out_dir_res  = 'ARRAY' eq ref $app_conf->{_output_dir} ? $app_conf->{_output_dir} : [ $app_conf->{_output_dir} ];
				my @data_dirs    = ();

				# grab all possible output dirs where we can potentialy have needed files
				for my $re (@$out_dir_res) {
					my @dirs = $re
								? grep {$_->is_folder && $_->path =~ /$re/} @$root_files 
								: grep {$_->is_folder} @$root_files;
					for my $out_dir (@dirs) {
						push @$root_files, @{ $io_ep->ls($out_dir) };

					}
					push @data_dirs, @dirs;
				}


				# grab all the files we need from the output directories
				my @data_files;
				for my $data_dir (@data_dirs) {
					print STDERR 'data_dir: ', $data_dir->path, $/ if ($debug);
					push @data_files, $out_files_re 
						? grep { $_->is_file && $_->size && $_->path =~ /$out_files_re/ } @{$io_ep->ls($data_dir->path)}
						: grep { $_->is_file } @{$io_ep->ls($data_dir->path)};
				}

				print STDERR "data_files:\n\t", join ("\n\t", @data_files), $/ if $debug;
				#
				# mark output file are shared so $DNALCADMIN user be able to read them
				my $ngs_cfg = DNALC::Pipeline::Config->new->cf('NGS');
				for (@data_files) {
					print STDERR  ' ++ sharing file ', $_->name, $/ if $debug;
					my $st = $io_ep->share($_->path, $ngs_cfg->{admin_user}, canRead => 1);
					$st = $io_ep->share($_->path, 'world', canRead => 1);
				}

				# further data handling (possibly download them)
				if ($app_conf->{_on_success} && $pm->can('task_' . $app_conf->{_on_success})) {
					my $output_handler = 'task_' . $app_conf->{_on_success};
					print STDERR  ' ++ output_handler: ', $output_handler, $/ if $debug;
					$pm->$output_handler($job, \@data_files);
				}
				else {
					print STDERR  " ++ No [_on_success] handler defined for [", $app_conf->{id},"]\n" if $debug;
					$pm->task_handle_default($job, \@data_files);
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

	# remove the cache flag as we're done with this job
	$mc->set($mc_key, 0, 5); # this will expire in 5 seconds
#
	$jt->update;

#	last;
}

exit 0;


