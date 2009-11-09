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
	$ua->timeout(600); # 10 minutes

	my $res;
	my $server = $cf->{TARGET_SERVER};
	my $post_url = $server . ($tp->type eq 'd' ? $cf->{DNA_URL} : $cf->{PROTEIN_URL});

	my $seq = $tp->seq;
	my @genomes = map {$_->genome_id->id} $tp->genomes;

	my $query = {
		'orgn[]' => \@genomes,
		'_querys_0' => $seq,
		'submit' => 'Tree'
	};


	my $xml_url;# = $server . '/Visitors/143_48_90_149/temp_0828144132.xml';
	#print STDERR Dumper( $query ), $/;

	unless ($xml_url) {
		$res = $ua->post($post_url, $query);
		#print STDERR Dumper( $res ), $/;
		unless ($res->is_success) {
			print STDERR $res->status_line, "\n";
			$tp->status('failed');
		}
		else {
			my $html = $res->content;
			#print "[$html]", $/;

			if ($html =~ /(\/Visitors.*\.xml)/s) {
				#print $1, $/;
				$xml_url = $server . $1;
			}
		}
	}
	print STDERR $xml_url, $/;

	if ($xml_url) {
		#print $xml_url, $/;
		$res = $ua->get($xml_url);
		unless ($res->is_success) {
			print STDERR $res->status_line, "\n";
			$tp->status('failed');
		}
		else {
			my @files = ();
			my $work_dir = $tp->work_dir;

			my $xml_str = $res->content;
			my $ref =  XMLin($xml_str);
			my $steps = $ref->{run}->{steps}->{step};
			if ($steps) {
				$tp->create_work_dir;
			
				if ( defined $steps->{Tree}) {
					my ($nw_file)  = grep {/\.nw$/} @{$steps->{Tree}->{program}->{output}};
					my ($jpg_file) = grep {/\.jpg$/} @{$steps->{Tree}->{program}->{output}};
					push @files, $jpg_file if $jpg_file;
					push @files, $nw_file if $nw_file;
				}

				if ( defined $steps->{Alignment}) {
					my ($fasta_file)  = grep {/\.fasta$/} @{$steps->{Alignment}->{program}->{output}};
					push @files, $fasta_file if $fasta_file;
				}
			}

			print STDERR Dumper( \@files ), $/;
			if (@files) {
				for (@files) {
					$_ =~ s{^\./}{/};
					my $file_url = $server . $_;
					#print STDERR  $file_url, $/;
					my ($ext) = ($_ =~ /\.(\w{2,5})$/);
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
		}

	}
	$tp->update;

   return 1;
}
#-------------------------------------------------

my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');
$worker->register_function("target", \&run_target);

$worker->work while 1;
