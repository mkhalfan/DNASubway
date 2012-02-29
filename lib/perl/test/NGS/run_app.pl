#!/usr/bin/perl 

use strict;
use warnings;

use DNALC::Pipeline::App::NGS::ProjectManager ();
use iPlant::FoundationalAPI::Constants ':all';
use iPlant::FoundationalAPI ();
use DNALC::Pipeline::Config ();
use Data::Dumper;

sub DEBUG {1};

my $app_id = "tophat-ranger-1.3.1";

my $api_instance = iPlant::FoundationalAPI->new(
		debug => undef,
		user => $ENV{iPLANT_USER},
		token => $ENV{iPLANT_TOKEN},
	);
#print STDERR Dumper( $api_instance), $/;
#$api_instance->debug(1);
die "Can't auth.." unless $api_instance->auth;
if ($api_instance->token eq kExitError) {
	print STDERR "Can't authenticate!" , $/;								
}
print "Token: ", $api_instance->token, "\n" if $api_instance;


my $pm = DNALC::Pipeline::App::NGS::ProjectManager->new({project => 5, debug => DEBUG});
$pm->api_instance($api_instance) if $api_instance;

#my $apps = $api_instance->apps;
#my ($app) = $apps->find_by_name($app_id);
my $app;
my $st = $pm->app($app_id);
unless ($st->{status} eq "success") {
	die "$app_id not found: ", $st->{msg}, $/;
}
else {
	$app = $st->{app};
}
#print STDERR $app->id, $/;
#print STDERR Dumper( $app ), $/;
__END__

my $th_cf = DNALC::Pipeline::Config->new->cf('NGS_TH');
my $app_inputs = $app->inputs;
my $app_params = $app->parameters;

my %conf_inputs = map {$_->{id} => $_} @{$th_cf->{inputs}};

my @inputs = ();
if (0) {
#print STDERR Dumper( $conf_inputs ), $/;
for my $input (@$app_inputs) {
	my $id = $input->{id};
	next unless defined($conf_inputs{$id});
	#print $id, "\t", $conf_inputs{$id}, $/;
	next if $conf_inputs{$id}->{hidden};

	$input->{display_type} = $conf_inputs{$id}->{display_type};
	$input->{value} = $conf_inputs{$id}->{value} if $conf_inputs{$id}->{value};
	$input->{label} = $conf_inputs{$id}->{label} if $conf_inputs{$id}->{label};

	push @inputs, $input;
}

}
else {
	my %app_inputs = map {$_->{id} => $_} @$app_inputs;

	for my $cf_input (@{$th_cf->{inputs}}) {
		my $id = $cf_input->{id};
		next unless defined($app_inputs{$id});
		my $input = $app_inputs{$id};
		print $id, "\t", $input->{id}, $/;

		#next if $cf_input->{$id}->{hidden};
		$input->{hidden} = $cf_input->{hidden} if $cf_input->{hidden};
		$input->{display_type} = $cf_input->{display_type};
		$input->{value} = $cf_input->{value} if $cf_input->{value};
		$input->{label} = $cf_input->{label} if $cf_input->{label};

		push @inputs, $input;
	}

}


	print "---\n";
	my @params = ();
	my %app_params = map {$_->{id} => $_} @$app_params;

	for my $cf_param (@{$th_cf->{parameters}}) {
		my $id = $cf_param->{id};
		next unless defined($app_params{$id});
		my $param = $app_params{$id};
		print $id, "\t", $param->{id}, $/;
		next;

		#next if $cf_input->{$id}->{hidden};
		$param->{hidden} = $cf_param->{hidden} if $cf_param->{hidden};
		$param->{display_type} = $cf_param->{display_type};
		$param->{value} = $cf_param->{value} if $cf_param->{value};
		$param->{label} = $cf_param->{label} if $cf_param->{label};

		push @params, $param;
	}

#print STDERR Dumper( \@inputs), $/;

