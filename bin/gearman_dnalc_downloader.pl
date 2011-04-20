#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::Config();

use HTTP::Tiny ();
use JSON::XS qw(decode_json);
use IO::File;
use File::Basename;
use Gearman::Worker ();
use Storable qw(nfreeze thaw);

#use Data::Dumper;

sub get_dnalc_files {
   my $gearman = shift;
   my $args = thaw ($gearman->arg);

   # args = {o => 24, ids => [523, 524, 525], dir => '/path/...'}
   my $bdir = "/tmp";
   my $dir = $bdir . '/' . $args->{dir};
   my $o = $args->{o};
   return unless ($o && $o =~ /^\d+$/ && -d $dir);

	my @flist = $args->{ids} && 'ARRAY' eq ref $args->{ids} ? @{$args->{ids}} : ();
	my $srv = "http://dnalc02.cshl.edu/genewiz/files?o=$o;f=" . join(',', @flist);
	#print $srv, $/;

	my $ht = HTTP::Tiny->new(timeout => 30 );
	my $response = $ht->get($srv);

	if ( $response->{success} && length $response->{content}) {
		my $data = eval { decode_json($response->{content}); };
		#print STDERR Dumper( $data ), $/;

		if ($data && 'ARRAY' eq ref $data) {
			my $i = 0;
			sleep 1;

			for (@$data) {
				#print $_->{id}, $/;
				my $file = my $url = $_->{file};
				$file =~ s/^.*\///;
				$file = $dir . '/' . $file;
				#print $url, $/;
				#print $file, $/;
				$ht->mirror($url, $file);
				$gearman->set_status ($i++, scalar @$data);
			}

			# emulate a touch
			IO::File->new($dir . '/.done', 'w');
		}
	}
   return nfreeze {dir => $dir};
}

#-------------------------------------------------

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');

my $worker = Gearman::Worker->new;
$worker->job_servers(@{$pcf->{GEARMAN_SERVERS}});

$worker->register_function("dnalc_files", \&get_dnalc_files);

#-------------------------------------------------
my $script_name = fileparse($0);
$script_name =~ s/\.[^.]*$//;

my $work_exit = 0;
my ($is_idle, $last_job_time);

my $stop_if = sub { 
	($is_idle, $last_job_time) = @_; 

	if ($work_exit) { 
		print STDERR  "*** [$script_name] exiting.. \n", $/;
		return 1; 
	}
	return 0; 
}; 

#-------------------------------------------------

$worker->register_function("${script_name}_exit" => sub { 
	$work_exit = 1; 
});

#-------------------------------------------------
$worker->work( stop_if => $stop_if ) while !$work_exit;

exit 0;

