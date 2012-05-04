#!/usr/bin/env perl

use strict;

use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::App::NGS::ProjectManager ();
use DNALC::Pipeline::User ();
use iPlant::FoundationalAPI ();
use File::Basename;

use Data::Dumper;

my $app_name = shift;
my $debug = shift;

unless ($app_name) {
	print "\nFoundational API 2 DNASubway app converter.\n";
	print "Usage:\n",
		"\tapi_app_to_config.pl <name|id>\n\n"
}

#----------------------

my $api_instance = iPlant::FoundationalAPI->new(
		debug => $debug,
		user => $ENV{iPLANT_USER},
		token => $ENV{iPLANT_TOKEN},
	);

unless ($api_instance) {
	print "\nError:\n",
		"Env vars iPLANT_USER and/or iPLANT_TOKEN not ser or token expired\n\n";

	exit 1;
}

my $app;

my $app_ep = $api_instance->apps;
my $apps = $app_ep->find_by_name($app_name);
if (@$apps) {
	#print STDERR Dumper( $apps), $/;
	# get by id
	if (1 < @$apps) {
		print "\nFound ", scalar @$apps, ":\n";
		print " + ", $_->id, " (", $_->{shortDescription}, ")", "\n" for (@$apps);
	}
	else {
		($app) = grep {($_->id eq $app_name) || ($_->name eq $app_name)} @$apps;
	}
}

if ($app) {
	#print STDERR Dumper( $app), $/;
	my @inputs = sort {$a->{id} cmp $b->{id}} @{$app->inputs};
	my @params = sort {$a->{id} cmp $b->{id}} @{$app->parameters};

	print 
		"{\n",
		"	id => '", $app->id, "',\n",
		"	name => '", $app->name, "',\n",
		"	desc => '", $app->{shortDescription}, "',\n",
		"	inputs => [\n",
			map({"\t\t{ id => '" . $_->{id} . "', display_type => '', hidden => 0, label => '". $_->{label} . "' },\n"} @inputs),
		"	],\n",
		"	parameters => [\n",
				map({
					my ($l, $v) = ($_->{label}, $_->{defaultValue});
					$l =~ s/'/\\'/g; $v =~ s/'/\\'/g;
					"\t\t{ id => '" . $_->{id} . "', label => '". $l . "', 'value' => '" . $v . "' },\n"
				} @params),
		"	],\n",
		"	_input_file_filter => '',\n",
		"	_output_dir => '',\n",
		"	_output_files => '',\n",
		"}\n";
}
