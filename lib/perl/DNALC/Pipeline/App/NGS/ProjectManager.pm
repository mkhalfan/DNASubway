package DNALC::Pipeline::App::NGS::ProjectManager;

#use common::sense;
use strict;
use warnings;

use aliased 'DNALC::Pipeline::NGS::Job';
use aliased 'DNALC::Pipeline::NGS::JobParam';
use aliased 'DNALC::Pipeline::NGS::Project';
use aliased 'DNALC::Pipeline::NGS::DataFile';
use aliased 'DNALC::Pipeline::NGS::DataSource';

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Task ();
use DNALC::Pipeline::TaskStatus ();

use iPlant::FoundationalAPI ();
use iPlant::FoundationalAPI::Constants ':all';

use JSON::XS ();
use Data::Dumper;

{
	sub new {
		my ($class, $params) = @_;
		my $self = bless {
			api_instance => undef,
			debug => $params->{debug} || undef,
		}, __PACKAGE__;

		my $project = $params->{project};

		if ($project) {
			if (ref $project eq '' && $project =~ /^\d+$/) {
				my $proj = Project->retrieve($project);
				unless ($proj) {
					print STDERR  "Project with id=$project wasn't found!", $/;
				}
				else {
					$self->project($proj);
				}
			}
			else { # we assume it's an instance of a project
				$self->project($project);
			}
		}

		$self;
	}

	# -------------------------------------
	sub create_project {
		my ($self, $params) = @_;

		my ($status, $msg) = ('fail', '');
		my $user_id = $params->{user_id};
		my $name = $params->{name};
			
		my $proj = $self->search(user_id => $user_id, name => $name);
		if ($proj){
			return {status => 'fail', msg => "There is already a project named \"$name\"."};
			print STDERR $msg, $/;
		}
			
		$proj = eval {
				Project->create({
						user_id => $user_id,
						name => $name,
						type => $params->{type} || '',
						organism => $params->{organism} || '',
						common_name => $params->{common_name} || '',
						description => $params->{description} || '',
					});
			};
		if ($@){
			$msg = "Error creating the project: $@";
			print STDERR $msg, $/;
			return {status => 'fail', msg => $msg};
		}

		$self->project($proj);

		return {status => 'success', msg => $msg};
	}

	#--------------------------------------
	sub add_data {
		my ($self, $params, $options) = @_;

		my (@errors, @warnings);

		my $bail_out = sub { return {errors => \@errors, warnings => \@warnings}};

		my $file_type = $params->{file_type} || '';

		my $_no_remote_check = defined $options ? $options->{_no_remote_check} : 0;
		if (!$_no_remote_check) {
			print STDERR  "__add_data__: Checking remote site to see if files exists.", $/ if $self->debug;
			my $io_api = $self->api_instance ? $self->api_instance->io : undef;
			if ($io_api) {
				my $files = $io_api->ls($params->{file_path});
				print STDERR Dumper( $files), $/;

				# TODO - what action should be taken when the file is not in the repository?
				unless (@$files) {
					print STDERR  "__add_data__: File not found in the iRODS repository: ", $params->{file_path}, $/;
				}
			}
		}
		else {
			print STDERR  "__add_data__: Not checking if file exists.", $/ if $self->debug;
		}

		my $data_src = DataSource->insert ({
				project_id => $self->project,
				name => $params->{source} || 'anonymous',
				note => 'note',
			});
		return $bail_out->() unless $data_src;

		my $data_file = DataFile->create({
				project_id => $self->project,
				source_id => $data_src,
				file_name => $params->{file_name},
				file_path => $params->{file_path},
				file_type => $file_type,
			});
	}
	
	#--------------------------------------
	sub data {
		my ($self, $filters) = @_;

		my %args = (
				project_id => $self->project,
			);
		DataFile->search(%args, {order_by => 'id'});
	}

	#--------------------------------------
	sub auth {
		my ($self, $user, $token) = @_;
		print STDERR "user: $user \n token: $token \n" if $self->debug;
		my $api_instance = iPlant::FoundationalAPI->new(
			user => $user,
			token => $token,
			debug => $self->debug,
		);

		print STDERR "Can't auth.." unless $api_instance->auth, $/;
		if ($api_instance->token eq kExitError) {
			print STDERR "Can't authenticate!" , $/;
			return kExitError;
		}
		$self->api_instance($api_instance);
	}

	#--------------------------------------
	# returns an hash { status => '[fail|success]', msg => '', app => $app},
	#	where $app is an instance of iPlant::FoundationalAPI::Object::Application
	#
	sub app {
		my ($self, $app_conf_file) = @_;

		unless ($app_conf_file) {
			return {status => 'fail', message => 'sub app: config file is missong the app id'};
		}

		my $app_cf = DNALC::Pipeline::Config->new->cf($app_conf_file);
		unless ($app_cf && $app_cf->{id}) {
			return {status => 'fail', message => 'sub app: config file is missong the app id'};
		}

		my $app_name = $app_cf->{name};
		unless ($app_name) {
			$app_name = $app_cf->{id};
			$app_name =~ s/-[\d.]*$//;
		}

		print STDERR  'app_name = ', $app_name, $/;

		my $api_instance = $self->api_instance;
		return {status => 'fail', message => 'sub app: no api_instance object'} unless $api_instance;

		my $app;

		my $app_ep = $api_instance->apps;
		my $apps = $app_ep->find_by_name($app_name);
		if (@$apps) {
			($app) = grep {$_->id eq $app_name} @$apps;
			$app ||= $apps->[0];

			# TODO : find a better name for the next method
			$self->apply_app_setting($app, $app_cf);

			return {status => 'success', app => $app };
		}

		# else ..
		print  STDERR "App $app_name not found sorry \n";
		return {status => 'fail', message => "Application $app_name not found"};
	}
	
	# apply our own configuration file for the app
	#	supply our own default values, or field labels, hide some of the fields
	sub apply_app_setting {
		my ($self, $app, $app_cf) = @_;


		# do we want t make sure we have exact version of the app?!
		return unless $app_cf->{id} eq $app->id;

		my $app_inputs = $app->inputs;
		my $app_params = $app->parameters;

		my %app_inputs = map {$_->{id} => $_} @$app_inputs;

		my @inputs = ();

		for my $cf_input (@{$app_cf->{inputs}}) {
			my $id = $cf_input->{id};
			next unless defined($app_inputs{$id});
			my $input = $app_inputs{$id};

			#next if $cf_input->{$id}->{hidden};
			$input->{hidden} = $cf_input->{hidden} if $cf_input->{hidden};
			$input->{display_type} = $cf_input->{display_type};
			$input->{value} = $cf_input->{value} if $cf_input->{value};
			$input->{label} = $cf_input->{label} if $cf_input->{label};

			push @inputs, $input;
		}

		$app->{inputs} = \@inputs if @inputs;

		my @params = ();
		my %app_params = map {$_->{id} => $_} @$app_params;

		for my $cf_param (@{$app_cf->{parameters}}) {
			my $id = $cf_param->{id};
			next unless defined($app_params{$id});
			my $param = $app_params{$id};

			#next if $cf_input->{$id}->{hidden};
			$param->{hidden} = $cf_param->{hidden} if $cf_param->{hidden};
			$param->{display_type} = $cf_param->{display_type};
			$param->{value} = $cf_param->{value} if $cf_param->{value};
			$param->{label} = $cf_param->{label} if $cf_param->{label};

			push @params, $param;
		}
		$app->{parameters} = \@params if @params;
	}
	#--------------------------------------
	sub job {
		my ($self, $app_id, $form_arguments) = @_;
		
		my $api_instance = $self->api_instance;
		return {status => 'fail', msg => 'sub job: no api_instance object'} unless $api_instance;
		
		my %job_arguments = %$form_arguments;
		my $apps = $api_instance->apps;
		my ($app) = $apps->find_by_name($app_id);
		print STDERR "APP: ", $app, $/;
		
		print STDERR "App ID: $app_id <br /> Annotation Field: $job_arguments{ANNOTATION} <br />";
		
		# adding additional 'hidden' arguments
		$job_arguments{jobName} = $app_id . '-DNAS-' . int(rand(100));
		$job_arguments{archive} = '1';
		$job_arguments{processors} = '1';
		$job_arguments{requested_time} = '11:11:11';
		$job_arguments{softwareName} = $app_id;
		
		print STDERR Dumper (%job_arguments);
		my $job_ep = $api_instance->job;
		my $job = $job_ep->submit_job($app, %job_arguments);
		#print STDERR "returned from submit_job: ", %$job, $/; 
	}

	sub submit_job {
		my ($self, $app, $params) = @_;

		my $apif = $self->api_instance;
		unless ($apif) {
			return _error('API instance not set.');
		}

		my $jobdb; #

		my $job_ep = $apif->job;
		my $job_st = $job_ep->submit_job($app, %$params);
		print STDERR  "ProjectManager::submit_job: ", Dumper($job_st), $/;
		if ($job_st && $job_st->{status} eq "success") {
			my $api_job = $job_st->{data};

			$jobdb = eval {DNALC::Pipeline::NGS::Job->create({
						api_job_id => $api_job->{id},
						project_id => 6,
						user_id => 90,
						task_id => 32,  # ngs_tophat
						status_id => 4, # processing/pending
					});
				};
			if ($@) {
				my $msg = $@;
				print STDERR  "Error: ", $msg, $/;
				return _error($msg);
			}
			else {
				print STDERR  "dbjob = ", $jobdb, $/;
				# add job parameters
				my @params = ();
				for my $type (qw/inputs parameters/) {
					my $sg_type = $type; $sg_type =~ s/s$//;
					for (@{$api_job->{$type}}) {
						my ($name, $value) = each %$_;
						eval {
							$jobdb->add_to_job_params({type => $sg_type, name => $name, value => $value || ''});
						};
					}
				}

				# add the rest of the job parameters
				for my $name (sort keys %$api_job) {
					next if $name =~ /^(?:inputs|parameters)$/;

					my $value = $api_job->{$name} || '';
					if (ref($value) eq 'ARRAY') {
						next if ref($value->[0]); # can't handle all situations
						$value = join ":", @$value;
					}
					$jobdb->add_to_job_params({type => '', name => $name, value => $value});
				}
			}
			return {status => 'success', job => $jobdb};
		}
		else {
			_error($job_st->{message} || 'Could not submit job.', data => $job_st->{data});
		}
	}

	#--------------------------------------
	sub search {
		my ($self, %args) = @_;
		Project->search(%args);
	}

	#---------------------------------------
	sub debug {
		my ($self, $debug) = @_;

		if (defined $debug) {
			$self->{debug} = $debug;
		}

		$self->{debug};
	}
	#---------------------------------------
	sub project {
		my ($self, $project) = @_;

		if ($project) {
			$self->{project} = $project;
		}

		$self->{project};
	}

	#---------------------------------------
	sub project_genome_path {
		my ($self) = @_;

		my $org = $self->project->organism;

		my $genomes = DNALC::Pipeline::Config->new->cf('NGS_GENOMES');
		my $genome_data = $genomes->{genomes}->{$org};
		my $path = $genomes->{store} . '/' . $org . '/' . $genome_data->{sub_part} 
			. '/' . $genome_data->{versions}->[0] . '/genome.fas';

		return $path;
	}

	#---------------------------------------
	sub project_annotation_path {
		my ($self) = @_;

		my $annotaion = $self->project_genome_path;
		$annotaion =~ s/genome\.fas$/annotation.gtf/;

		return $annotaion;
	}
	#--------------------------------------
	sub api_instance {
		my ($self, $api_instance) = @_;

		if ($api_instance) {
			$self->{api_instance} = $api_instance;
		}

		$self->{api_instance};
	}

	sub _error {
		my ($self, $msg) = @_;
		if (!defined $msg && !ref($self)) {
			$msg = $self;
		}

		return {status => 'fail', msg => $msg || 'Unspecified error.'};
	}
}

1;
