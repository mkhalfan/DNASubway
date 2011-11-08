#!/usr/bin/perl

use strict;
use DNALC::Pipeline::App::NGS::ProjectManager;
use iPlant::FoundationalAPI ();
use iPlant::FoundationalAPI::Constants ':all';


my $pm = DNALC::Pipeline::App::NGS::ProjectManager->new;

if (0){
my $st = $pm->create_project({
	user_id => 693,
	name => 'testing the project manager6',
	type => 'Transcript Abundance',
	organism => 'Panthera leo',
	common_name => 'lion',
	description => 'i like lions',
});

if ($st->{status} eq 'fail') {
	die $st->{msg};
}

$pm->add_data({
	source_id => 1,
	file_name => 'lion.fasta',
	file_path => '/mkhalfan/analysis/new/',
	file_type => 'fasta',
});
} # end if (0)

#$pm->auth();
#$pm->app('wc-0.11');

if (0){
	my $api_instance = iPlant::FoundationalAPI->new(
		user => 'mkhalfan',
		token => 'f789f422dcd9ecb9c6035c4b5cd6e913',
		debug => 1,
	);
	#$api_instance->debug(1);
	die "Can't auth.." unless $api_instance->auth;
	if ($api_instance->token eq kExitError) {
		print STDERR "Can't authenticate!" , $/;								
	}
	print "Token: ", $api_instance->token, "\n";
}

