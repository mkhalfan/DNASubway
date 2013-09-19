package iPlant::FoundationalAPI::Transport;

use strict;
use warnings;

use Carp;
use File::HomeDir ();
#use File::Basename qw/dirname/;
use Data::Dumper;


our $VERSION = '0.11';
use vars qw($VERSION);

use iPlant::FoundationalAPI::Constants ':all';
    
use LWP;
# Emit verbose HTTP traffic logs to STDERR. Uncomment
# to see detailed (and I mean detailed) HTTP traffic
#use LWP::Debug qw/+/;
use HTTP::Request::Common qw(POST);
# Needed to emit the curl-compatible form when DEBUG is enabled
use URI::Escape;
# For handling the JSON that comes back from iPlant services
use JSON::XS;
# Used for exporting complex data structures to text. Mainly used here 
# for debugging. May be removed as a dependency later
#use YAML qw(Dump);
use MIME::Base64 qw(encode_base64);

use constant kMaximumSleepSeconds => 600; # 10 min

# these should be moved to a config file (or not?)

# Never subject to configuration
my $ZONE = 'iPlant Job Service';
my $AGENT = "iPlantRobot/0.1 ";

# Define API endpoints
my $IO_ROOT = "io-v1";
my $IO_END = "$IO_ROOT/io";

my $AUTH_ROOT = "auth-v1";
my $AUTH_END = $AUTH_ROOT;

my $DATA_ROOT = "data-v1";
my $DATA_END = "$DATA_ROOT/data";

my $APPS_ROOT = "apps-v1";
my $APPS_END = "$APPS_ROOT/apps";
my $APPS_SHARE_END = "$APPS_ROOT/apps/share/name";

my $JOB_END = "$APPS_ROOT/job";
my $JOBS_END = "$APPS_ROOT/jobs";

my $TRANSPORT = 'https';

my %end_point = (
		auth => $AUTH_END,
		io => $IO_END,
		data => $DATA_END,
		apps => $APPS_END,
		job => $JOB_END,
	);



sub _get_end_point {
	my $self = shift;

	my $ref_name = ref $self;
	return unless $ref_name;
	$ref_name =~ s/^.*:://;

	return $end_point{lc $ref_name};
}

sub do_get {

	my ($self, $path, %params) = @_;

	my $END_POINT = $self->_get_end_point;
	print STDERR  $END_POINT, $/ if $self->debug;
	unless ($END_POINT) {
		print STDERR "::do_get: invalid request: ", $self, $/ if $self->debug;
		return kExitError;
	}
	
	# Check for a request path
	unless (defined($path)) {
		print STDERR "Please specify a RESTful path using for ", $END_POINT, $/ if $self->debug;
		return kExitError;
	}
	print STDERR  "::do_get: path: ", $path, $/ if $self->debug;

	my $ua = _setup_user_agent($self);
	my ($req, $res);

	if (defined $params{limit_size} || defined $params{save_to} || defined $params{stream_to_stdout}) {

		my $data;

		if ($params{save_to}) {
			my $filepath = $params{save_to};
			# should we at least check if parent directory exists?

			$res = $ua->get("$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path,
						':content_file' => $filepath,
					);
			$data = 1;
		}
		elsif ($params{stream_to_stdout}) {
			$res = $ua->get("$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path,
						#':read_size_hint' => $params{limit_size} > 0 ? $params{limit_size} : undef,
						':content_cb' => sub {my ($d)= @_; print STDOUT $d;},
					);
			$data = 1;
		}

		else {
			$res = $ua->get("$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path,
						':read_size_hint' => $params{limit_size} > 0 ? $params{limit_size} : undef,
						':content_cb' => sub {my ($d)= @_; $data = $d; die();},
					);
		}
		if ($res->is_success) {
			return $data;
		}
		else {
			print STDERR $res->status_line, "\n" if $self->debug;
			print STDERR $req->content, "\n" if $self->debug;
		
			return kExitError;
		}
	}
	else {
		$req = HTTP::Request->new(GET => "$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path);
		$res = $ua->request($req);
	}
	
	print STDERR "\n$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path, "\n" if $self->debug;
	
	# Parse response
	my $message;
	my $mref;
	
	print STDERR Dumper( $res ), $/ if $self->debug;
	if ($res->is_success) {
		$message = $res->content;
		print STDERR $message, "\n" if $self->debug;

		my $json = JSON::XS->new->allow_nonref;
		$mref = $json->decode( $message );
		# mref in this case is an array reference
		#_display_io_list_reference($mref->{'result'});
		#return kExitOK;
		return $mref->{result};
	}
	else {
		print STDERR $res->status_line, "\n" if $self->debug;
		print STDERR $req->content, "\n" if $self->debug;
		return kExitError;
	}
}

sub do_put {

	my ($self, $path, %params) = @_;

	my $END_POINT = $self->_get_end_point;
	unless ($END_POINT) {
		print STDERR  "Invalid request. ", $/ if $self->debug;
		return kExitError;
	}
	
	# Check for a request path
	unless (defined($path)) {
		print STDERR "Please specify a RESTful path using for ", $END_POINT, $/ if $self->debug;
		return kExitError;
	}
	print STDERR  "Path: ", $path, $/ if $self->debug;

	print STDERR '::do_put: ', Dumper( \%params), $/ if $self->debug;
	my $content = '';
	while (my ($k, $v) = each %params) {
		$content .= "$k=$v&";
	}

	my $ua = _setup_user_agent($self);
	print STDERR Dumper( $ua), $/ if $self->debug;
	print STDERR "\n$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path, "\n" if $self->debug;
	my $req = HTTP::Request->new(PUT => "$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path);
	$req->content($content) if $content;
	my $res = $ua->request($req);
	
	# Parse response
	my $message;
	my $mref;
	
	print STDERR Dumper( $res ), $/ if $self->debug;
	if ($res->is_success) {
		$message = $res->content;
		print STDERR $message, "\n" if $self->debug;
		my $json = JSON::XS->new->allow_nonref;
		$mref = eval {$json->decode( $message );};
		#return kExitOK;
		return $mref;
	}
	else {
		print STDERR $res->status_line, "\n" if $self->debug;
		return kExitError;
	}
}

sub do_delete {

	my ($self, $path) = @_;

	my $END_POINT = $self->_get_end_point;
	unless ($END_POINT) {
		print STDERR  "Invalid request. ", $/ if $self->debug;
		return kExitError;
	}
	
	# Check for a request path
	unless (defined($path)) {
		print STDERR "Please specify a RESTful path using for ", $END_POINT, $/ if $self->debug;
		return kExitError;
	}
	print STDERR  "DELETE Path: ", $path, $/ if $self->debug;

	my $ua = _setup_user_agent($self);
	my $req = HTTP::Request->new(DELETE => "$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path);
	my $res = $ua->request($req);
	
	print STDERR "\nDELETE => $TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path, "\n" if $self->debug;
	
	# Parse response
	my $message;
	my $mref;
	
	if ($res->is_success) {
		$message = $res->content;
		print STDERR $message, "\n" if $self->debug;

		my $json = JSON::XS->new->allow_nonref;
		$mref = eval { $json->decode( $message ); };
		if ($mref && $mref->{status} eq 'success') {
			return 1;
		}
		return $mref;
	}
	else {
		print STDERR $res->status_line, "\n" if $self->debug;
		print STDERR $res->content, $/ if $self->debug;
		return kExitError;
	}
}


sub do_post {

	my ($self, $path, %params) = @_;

	my $END_POINT = $self->_get_end_point;
	unless ($END_POINT) {
		print STDERR  "Invalid request. ", $/ if $self->debug;
		return kExitError;
	}
	
	# Check for a request path
	unless (defined($path)) {
		print STDERR "Please specify a RESTful path using for ", $END_POINT, $/ if $self->debug;
		return kExitError;
	}

	$path =~ s'/$'';

	print STDERR '::do_post: ', Dumper( \%params), $/ if $self->debug;
	print STDERR "\n$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path, "\n" if $self->debug;

	my $ua = $self->_setup_user_agent;
	my $res = $ua->post(
				"$TRANSPORT://" . $self->hostname . "/" . $END_POINT . $path,
				\%params
			);
	
	# Parse response
	my $message;
	my $mref;
	
	my $json = JSON::XS->new->allow_nonref;
	if ($res->is_success) {
		$message = $res->content;
		if ($self->debug) {
			print STDERR '::do_post content: ', $message, "\n" if $self->debug;
		}
		$mref = eval {$json->decode( $message );};
		if ($mref && $mref->{status} eq 'success') {
			return $mref->{result};
		}
		return $mref;
	}
	else {
		print STDERR Dumper( $res ), $/ if $self->debug;
		print STDERR "Status line: ", (caller(0))[3], " ", $res->status_line, "\n" if $self->debug;
		my $content = $res->content;
		print STDERR "Content: ", $content, $/ if $self->debug;
		if ($content =~ /"status":/) {
			$mref = eval {$json->decode( $content );};
			if ($mref && $mref->{status}) {
				return {status => "error", message => $mref->{message} || $res->status_line};
			}
		}
		return {status => "error", message => $res->status_line};
	}
}

# Transport-level Methods
sub _setup_user_agent {
	
	my $self = shift;
	my $ua = LWP::UserAgent->new;
	
	$ua->agent($AGENT);
	if (($self->user ne '') and ($self->token ne '')) {
		if ($self->debug) {
			print STDERR (caller(0))[3], ": Username/token authentication selected\n" if $self->debug;
		}
		$ua->default_header( Authorization => 'Basic ' . _encode_credentials($self->user, $self->token) );
	} else {
		if ($self->debug) {
			print STDERR (caller(0))[3], ": Sending no authentication information\n" if $self->debug;
		}
	}
	
	return $ua;

}

sub _encode_credentials {
	
	# u is always an iPlant username
	# p can be either a password or RSA encrypted token
	
	my ($u, $p) = @_;
	encode_base64("$u:$p");
}

sub debug {
	my $self = shift;
	if (@_) { $self->{debug} = shift }
	return $self->{debug};
}


1;
