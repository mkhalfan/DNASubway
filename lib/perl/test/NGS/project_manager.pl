#!/usr/bin/perl

use strict;
use DNALC::Pipeline::App::NGS::ProjectManager;
use iPlant::FoundationalAPI ();
use iPlant::FoundationalAPI::Constants ':all';

use File::Basename;

use Data::Dumper;

# constants
sub DEBUG {1};

#----------------------

#1 authenticate
#2 create project
#3 add data/load data from store
#4 get application to run
#5 set parameters for application
#6 create job
#7 poll for job status


#1 authenticate
my $api_instance;
if (1) {
	$api_instance = iPlant::FoundationalAPI->new(
		debug => DEBUG,
		user => 'ghiban',
		token => '358fbc1fc404051f24eed5f9490c6a1c',
	);
	#print STDERR Dumper( $api_instance), $/;
	#$api_instance->debug(1);
	die "Can't auth.." unless $api_instance->auth;
	if ($api_instance->token eq kExitError) {
		print STDERR "Can't authenticate!" , $/;								
	}
	print "Token: ", $api_instance->token, "\n" if $;
}

#2 create project
my $pm;
if (0){
	$pm = DNALC::Pipeline::App::NGS::ProjectManager->new({debug => DEBUG});
	my @lt = (localtime)[0..2];
	my $st = $pm->create_project({
		user_id => 90, #corbel
		name => sprintf('testing the project manager-%02d-%02d-%02d', reverse @lt),
		type => 'Transcript Abundance',
		organism => 'Panthera leo',
		common_name => 'leo paraleo',
		description => 'i like lions',
	});

	if ($st->{status} eq 'fail') {
		die $st->{status} . " : " . $st->{msg}, $/;
	}
}
else {
	$pm = DNALC::Pipeline::App::NGS::ProjectManager->new({project => 3, debug => DEBUG});
}

unless ($pm->project) {
	print STDERR  "Can't find project!", $/;
	die;
}


$pm->api_instance($api_instance) if $api_instance;
print STDERR  "\n***\n Working on project: ", $pm->project->name, "\n***\n";

#3 add data

my $file = "/ghiban/SRX030194_slimer.fastq";

$pm->add_data({
		source_id => 1,
		file_name => basename($file),
		file_path => $file,
		file_type => 'fastq',
	},
	{_no_remote_check => 0}	
);

__END__

#$pm->auth();
#$pm->app('wc-0.11');



