#!/usr/bin/perl 

use strict;
use lib "/var/www/lib/perl";

use Data::Dumper;
use Gearman::Worker ();
#use Storable qw(freeze);

use LWP::UserAgent;
use XML::Simple;
use DNALC::Pipeline::TargetProject ();
use DNALC::Pipeline::Config();


sub run_target {
	my $gearman = shift;
	my $tpid = $gearman->arg;

	my $tp = DNALC::Pipeline::TargetProject->retrieve($tpid);

	my $cf = DNALC::Pipeline::Config->new->cf('TARGET');
	my $ua = LWP::UserAgent->new;
	$ua->agent("pipeline.dnalc.org");

	my $res;
	my $server = $cf->{TARGET_SERVER};
	my $post_url = $server . $cf->{DNA_URL};

	my $seq = $tp->seq;
	my @genomes = map {$_->genome_id->id} $tp->genomes;

	my $query = {
		'orgn[]' => \@genomes,
		'_querys_0' => $seq,
		'submit' => 'Tree'
	};

	#print STDERR Dumper( $query ), $/;

	my $xml_url;# = $server . '/Visitors/143_48_90_149/temp_0826130445.xml';

	unless ($xml_url) {
		$res = $ua->post($post_url, $query);
		unless ($res->is_success) {
			print $res->status_line, "\n";
		}
		else {
			my $html = $res->content;
			#print "[$html]", $/;

			if ($html =~ /(\/Visitors.*\.xml)/s) {
				print $1, $/;
				$xml_url = $server . $1;
			}
		}
	}

	if ($xml_url) {
		#print $xml_url, $/;
		$res = $ua->get($xml_url);
		unless ($res->is_success) {
			print $res->status_line, "\n";
			$tp->status('failed');
		}
		else {
			my $xml_str = $res->content;
			my $ref =  XMLin($xml_str);
			my $steps = $ref->{run}->{steps}->{step};
			if ($steps && defined $steps->{Tree}) {
				my ($nw_file)  = grep {/\.nw$/} @{$steps->{Tree}->{program}->{output}};
				my ($jpg_file) = grep {/\.jpg$/} @{$steps->{Tree}->{program}->{output}};
				#print STDERR Dumper( $steps->{Tree}->{program}), $/;
				if ($nw_file || $jpg_file) {
					$tp->create_work_dir;
					my $work_dir = $tp->work_dir;
					for ($nw_file, $jpg_file) {
						$_ =~ s{^\./}{/};
						my $file_url = $server . $_;
						print STDERR  $file_url, $/;
						my ($ext) = ($_ =~ /\.(\w{2,4})$/);
						$ext ||= 'txt';
						$res = $ua->get( $file_url );
						unless ($res->is_success) {
							print STDERR 'Err: ', $res->status_line, "\n";
						}
						else {
							my $content = $res->content;
							my $file = $work_dir . '/file.' . $ext;
							my $fh = IO::File->new;
							if ($fh->open( $file , 'w')) {
								$fh->binmode if $ext eq 'jpg';
								print $fh $content;
								$fh->close;
							}
							#print STDERR  $file, $/;
						}
					}
					$tp->status('done');
				}
				else {
					$tp->status('done-empty');
				}
				print "nw file = ", $nw_file, $/;
				print "jpg file = ", $jpg_file, $/;
			}
			else {
				print "nema...\n";
				$tp->status('done-empty');
			}
		}

		$tp->update;
	}

   return 1;
}
#-------------------------------------------------

my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');
$worker->register_function("target", \&run_target);

$worker->work while 1;
