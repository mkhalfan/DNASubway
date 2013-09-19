#!/usr/bin/perl 

use common::sense;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use DNALC::Pipeline::Config();

use HTTP::Tiny ();
use JSON::XS qw(decode_json);
use IO::File;
use File::Basename;
use Gearman::Worker ();
use Storable qw(nfreeze thaw);
use Parallel::ForkManager ();

#use Data::Dumper;

sub get_dnalc_files {
   my $gearman = shift;
   my $args = thaw ($gearman->arg);

   # args = {o => 24, ids => [523, 524, 525], dir => '/path/...'}
   my $cf = DNALC::Pipeline::Config->new->cf('PHYLOGENETICS');
   my $base_dir = $cf->{DNALC_TRANSFER_DIR} || "/tmp";

   my $dir = $base_dir . '/' . $args->{dir};
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

			my $pm;
			if (@$data >= 6) {
				$pm = new Parallel::ForkManager(3) ;
				$pm->run_on_finish( sub {
					$gearman->set_status ($i++, scalar @$data);
					#print STDERR sprintf "%s : Process completed: @_\n", $i, $/;
				});
			}

			for (@$data) {
				if ($pm) {
					$pm->start and next;
				}
				my $file = my $url = $_->{file};
				$file =~ s/^.*\///;
				$file = $dir . '/' . $file;
				$ht->mirror($url, $file);
				if ($pm) {
					$pm->finish 
				}
				else {
					$gearman->set_status ($i++, scalar @$data);
				}
			}

			$pm->wait_all_children if $pm;

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

