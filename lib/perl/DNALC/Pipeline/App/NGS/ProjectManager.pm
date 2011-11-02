package DNALC::Pipeline::App::NGS::ProjectManager;

use common::sense;

use Data::Dumper;
use JSON::XS ();

use aliased 'DNALC::Pipeline::NGS::Job';
use aliased 'DNALC::Pipeline::NGS::JobParam';
use aliased 'DNALC::Pipeline::NGS::Project';
use aliased 'DNALC::Pipeline::NGS::DataFile';
use aliased 'DNALC::Pipeline::NGS::DataSource';

use DNALC::Pipeline::Task ();
use DNALC::Pipeline::TaskStatus ();

use iPlant::FoundationalAPI ();
use iPlant::FoundationalAPI::Constants ':all';

{
	sub new {
		my ($class, %args) = @_;
		my $self = bless {
			api_instance => undef,
		}, __PACKAGE__;


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
						type => $params->{type},
						organism => $params->{organism},
						common_name => $params->{common_name},
						description => $params->{description},
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
		my ($self, $params) = @_;

		my $data_file = DataFile->create({
				project_id => $self->project,
				source_id => $params->{source_id},
				file_name => $params->{file_name},
				file_path => $params->{file_path},
				file_type => $params->{file_type},
			});

	}
	
	#--------------------------------------
	sub auth {
		my ($self, $user, $token) = @_;
		print STDERR "user: $user \n token: $token \n";
		my $api_instance = iPlant::FoundationalAPI->new(
			user => $user,
			token => $token,
			debug => 1,
		);

		die "Can't auth.." unless $api_instance->auth;
		if ($api_instance->token eq kExitError) {
			print STDERR "Can't authenticate!" , $/;
			exit 1;
		}
		$self->api_instance($api_instance);
		#print "Token: ", $api_instance->token, "\n";

	}

	#--------------------------------------
	sub app {
		my ($self, $app_name) = @_;

		my $api_instance = $self->api_instance;
		return {status => 'fail', msg => 'no api_instance object'} unless $api_instance;

		my $apps = $api_instance->apps;
		my $app = $apps->find_by_name($app_name);
		if (@$app){
			#print STDERR Dumper ($app);
			#print "App $app_name found \n";
			
			# INPUTS
			my $inputs = $app->[0]->inputs();
			#print STDERR Dumper ($inputs), $/;
			#my $x = 0;
			#foreach (@$inputs){
			#	my %hash = %$_;
			#	$x++;
			#	print "Input $x: \n";
			#	while (my ($key, $value) = each %hash){
			#		print "$key = $value \n";
			#	}
			#	print $/;
			#}

			# PARAMS
			my $params = $app->[0]->parameters();
			#my $x = 0;
			#foreach(@$params){
			#	my %hash = %$_;
			#	$x++;
			#	print "Parameter $x: \n";
			#	while (my ($key, $value) = each %hash){
			#		print "$key = $value \n";
			#	}
			#	print $/;
			#}
			return {status => 'success', inputs => $inputs, params => $params};

		}

		else{
			return {status => 'fail', msg => "App $app_name not found"};
			print  STDERR "App $app_name not found sorry \n";
		}

	}

	#--------------------------------------
	sub search {
		my ($self, %args) = @_;
		Project->search(%args);
	}

	#---------------------------------------
	sub project {
		my ($self, $project) = @_;

		if ($project) {
			$self->{project} = $project;
		}

		$self->{project};
	}

	#--------------------------------------
	sub api_instance {
		my ($self, $api_instance) = @_;

		if ($api_instance) {
			$self->{api_instance} = $api_instance;
		}

		$self->{api_instance};
	}
}

1;
