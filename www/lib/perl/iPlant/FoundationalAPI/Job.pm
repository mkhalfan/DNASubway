package iPlant::FoundationalAPI::Job;

use warnings;
use strict;

use iPlant::FoundationalAPI::Constants ':all';
use base qw/iPlant::FoundationalAPI::Base/;

use iPlant::FoundationalAPI::Object::Job ();

use Data::Dumper;

=head1 NAME

iPlant::FoundationalAPI::Job - The great new iPlant::FoundationalAPI::Job!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use iPlant::FoundationalAPI::Job;

    my $foo = iPlant::FoundationalAPI::Job->new();
    ...

=head1 METHODS

=head2 submit_job

    Submits a request to run a job.
    Returns a hashref: {status => [success|fail], message => '..', data => $job}
    where $job is a Job object.

	$apps = $api_instance->apps;
	$job = $api_instance->job;
	($ap) = $apps->find_by_name("name"); #iPlant::FoundationalAPI::Object::Application
	$job->submit_job($ap, %arguments)

=cut

sub submit_job {
	my ($self, $application, %params) = @_;

	print STDERR  '$application: ', $application, $/ if $self->debug;
	print STDERR  'ref $application: ', ref $application, $/ if $self->debug;
	unless ($application && ref($application) =~ /::Application/) {
		print STDERR  "::submit_job: Invalid argument. Expecting Application object", $/ if $self->debug;
		return $self->_error("Invalid argument. Expecting Application object.");
	}


	my %required_options = ();
	my %available_options = ();

	# fix jobName
	if (defined $params{jobName} && $params{jobName} ne "") {
		$params{jobName} =~ s|/+||g;
		$params{jobName} =~ s|^\d|N|;
	}

        my $jobName = $application->name;
	$jobName =~ s/dnalc-|-stampede\S*//g;

	my %post_content = (
			softwareName => $application->id,
			jobName => $params{jobName} || $jobName . $$,
			requestedTime => delete $params{requestedTime} || '0:10:00',
			processors => delete $params{processors} || 1,
			memory => delete $params{memory} || '',
			archive => delete $params{archive} || 'false',
			archivePath => delete $params{archivePath} || undef,
			callbackUrl => delete $params{callbackUrl} || undef,
		);

	for my $opt_group (qw/inputs outputs parameters/) {
		for my $opt ($application->$opt_group) {
			print STDERR  "  ** ", $opt->{id}, 
				"\tr:", defined $opt->{required} ? $opt->{required} : '',
				"\tv:", defined $opt->{validator} ? $opt->{validator} : '',
				$/ if $self->debug;
			#$available_options{$opt->{id}} = $opt;
			if (defined $params{$opt->{id}} && $params{$opt->{id}} ne "") {
				$post_content{ $opt->{id} } = $params{$opt->{id}};
			}
			elsif (defined $opt->{required} && $opt->{required}) {
				$required_options{$opt->{id}} = $opt_group;
			}
		}
	}

	if (%required_options) {
		return $self->_error("Missing required argument(s)", \%required_options);
	}

	my $resp = $self->do_post('/', %post_content);
	if ($resp != kExitError) {
		print STDERR  "vvvvvvvvvvvvvvvv THE JOB vvvvvvvvvvvvvvvvvvv", $/ if $self->debug;
		if ($resp->{id}) {
			return { status => 'success', data => iPlant::FoundationalAPI::Object::Job->new($resp) };
		}
		#else...
		return $resp;
	}
	return $self->_error("JobEP: Unable to submit job.", $resp);
}

=head2 job_details

=cut

sub job_details {
	my ($self, $job_id) = @_;

	my $data = $self->do_get('/' . $job_id);
	if ('HASH' eq ref $data) {
		return iPlant::FoundationalAPI::Object::Job->new($data);
	}

	return $data;
}

sub job_output_files {
	my ($self, $job_id) = @_;

	$self->do_get('/' . $job_id . '/output/list');
}

=head2 jobs

=cut

sub jobs {
	my ($self) = @_;

	$self->do_get('s/list');
}


=head2 delete_job

    Kills a running job identified by <id> and removes it from history

=cut

sub delete_job {
	my ($self, $job_id) = @_;

	my $st = $self->do_delete('/' . $job_id);

	return 1 if ($st != 1);
	return;
}

=head2 input

=cut

sub input {
	my ($self, $job_id) = @_;

	$self->do_get('/' . $job_id . '/input');
}



=head1 AUTHOR

Cornel Ghiban, C<< <ghiban at cshl.edu> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-iplant-foundationalapi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=iPlant-FoundationalAPI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc iPlant::FoundationalAPI

=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2011 Cornel Ghiban.

=cut

1; # End of iPlant::FoundationalAPI::Job
