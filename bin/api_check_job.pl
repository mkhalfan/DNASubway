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

		if ($api_status =~ /(?:FINISHED|KILLED|FAILED|STOPPED|ARCHIVING_FINISHED|ARCHIVING_FAILED)/) {
			# the job hit a terminal stage: it will not change it's status

			$jt->token('');
			if ($api_status =~ /(?:FINISHED|ARCHIVING_FINISHED)/) {
				$jt->tracker_status('success');
				$job->status_id(2); # done

				my $task = $job->task_id->name;

 				print STDERR  'task = ', $task, $/ if $debug;

				my $job_name = $job->attrs->{name};
				my $app_conf = DNALC::Pipeline::Config->new->cf(uc $task);

				my $io_ep = $fapi->io;
				my $all_files    = $io_ep->ls($api_job->{archivePath});
				my $out_dir_re   = $app_conf->{_output_dir};
				my $out_files_re = $app_conf->{_output_files};
				my ($data_dir)   = $out_dir_re ? grep {$_->path =~ /$out_dir_re/} @$all_files : @$all_files;
				print STDERR 'data_dir: ', $data_dir->path, $/ if ($debug && $data_dir);

				my @data_files;
				if ($data_dir) {
					@data_files = $out_files_re 
						? grep { $_->path =~ /$out_files_re/ } @{$io_ep->ls($data_dir->path)}
						: @{$io_ep->ls($data_dir->path)};
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

				my $src_id;

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

#
	$jt->update;

#	last;
}

exit 0;


