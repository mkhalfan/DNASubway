#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use Data::Dumper;
use Gearman::Worker ();
#use Storable qw(freeze);

use LWP::UserAgent;
use XML::Simple;
use DNALC::Pipeline::TargetProject ();
use DNALC::Pipeline::Config();
use Archive::Tar;
use File::Basename;

sub run_target {
	my $gearman = shift;
	my $tpid = $gearman->arg;

	my $tp = DNALC::Pipeline::TargetProject->retrieve($tpid);
	return unless $tp;
	#print STDERR  'Working on Target Project: ', $tp->id, $/;

	my $cf = DNALC::Pipeline::Config->new->cf('TARGET');
	my $ua = LWP::UserAgent->new;
	$ua->agent("pipeline.dnalc.org");
	$ua->timeout(600); # 10 minutes

	my $res;
	my $server = $cf->{TARGET_SERVER};
	my $post_url = $server . ($tp->type eq 'd' ? $cf->{DNA_URL} : $cf->{PROTEIN_URL});

	my $seq = $tp->seq;
	my @genomes = map {$_->genome_id->id} $tp->genomes;
	my %genomes = map {my $o = $_->genome_id->organism; $o =~ s/\s+/_/g;$_->genome_id->id => $o} $tp->genomes;

	my $query = {
		'orgn[]' => \@genomes,
		'_querys_0' => $seq,
		'submit' => 'Tree'
	};


	my $xml_url;# = $server . '/Visitors/143_48_90_149/temp_0310151334.xml';
	#print STDERR Dumper( $query ), $/;

	#----------------------------------------------------------------
	my $archive = '';

	unless ($xml_url) {
		$res = $ua->post($post_url, $query);
		print STDERR 'got POST response; is_success: ', $res->is_success, $/;
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

	if ($xml_url) {
		#print $xml_url, $/;
		print STDERR "getting XML file: ", $xml_url, $/;
		$res = $ua->get($xml_url);
		print STDERR "got XML file.. ", $/;
		unless ($res->is_success) {
			print STDERR $res->status_line, "\n";
			$tp->status('failed');
		}
		else {
			my @files = ();
			my $work_dir = $tp->work_dir;

			my $xml_str = $res->content;
			my $ref = XMLin($xml_str);
			my $steps = $ref->{run}->{steps}->{step};

			if ($ref->{run}->{other} && $ref->{run}->{other}->{archive}) {
				$archive = $ref->{run}->{other}->{archive};
			}

			if ($steps) {
				if ( defined $steps->{Tree}) {
					my ($nw_file)  = grep {/\.nw$/} @{$steps->{Tree}->{program}->{output}};
					#my ($jpg_file) = grep {/\.jpg$/} @{$steps->{Tree}->{program}->{output}};
					#push @files, $jpg_file if $jpg_file;
					push @files, $nw_file if $nw_file;
				}

				if ( defined $steps->{Alignment}) {
					my ($fasta_file)  = grep {/\.fasta$/} @{$steps->{Alignment}->{program}->{output}};
					push @files, $fasta_file if $fasta_file;
				}
			}

			#print STDERR Dumper( \@files ), $/;
			if (@files) {
				$tp->create_work_dir;

				push @files, $archive if $archive;

				for (@files) {
					$_ =~ s{^\./}{/};
					my $file_url = $server . $_;
					#print STDERR  $file_url, $/;
					my ($ext) = ($_ =~ /\.(\w{2,5})$/);
					$ext ||= 'dat';
					$res = $ua->get( $file_url );
					unless ($res->is_success) {
						print STDERR 'Err: ', $res->status_line, "for file: ", $file_url, "\n";
					}
					else {
						my $content = $res->content;
						my $file = $work_dir . '/file.' . $ext;
						my $fh = IO::File->new;
						if ($fh->open( $file , 'w')) {
							if ($ext eq 'nw') {
								#print STDERR  $content, $/, $/;
								#$content =~ s/([a-z0-9_]+)_AS_/$genomes{$1} . '_AS_'/gei;
								$content =~ s/(\d+)_([A-Z][a-z0-9_]+):0/$2-$1-$tpid:0/gi;
								#print STDERR  $content, $/;
							}
							elsif ($ext eq 'fasta') {
								#$content =~ s/^>([a-z0-9_]+)_AS_/'>' . $genomes{$1} . '_AS_'/mgei;
								$content =~ s/^>(\d+)_([A-Z][a-z0-9_]+)/>$2-$1-$tpid/mgi;
								#print STDERR $content, $/;
							}
							else {
								$fh->binmode if $ext =~ /(?:gz|jpg)/;
							}
							print $fh $content;
							$fh->close;

							if ($ext eq 'gz') {
								$archive = $file;
							}
						}
						else {
							print STDERR  "Unable to write file: ", $file, $/;
						}
					}
				}
				if ($archive && -f $archive && Archive::Tar->can_handle_compressed_files) {
					my $tar = Archive::Tar->new($archive, 1);
					$tar->setcwd( $work_dir );
					my @list = grep {$_->{name} =~ /\.flank$/ 
							&& $_->{size}} $tar->list_files([qw/name size/]);
					for (@list) {
						my $filename = basename($_->{name});
						$filename =~ s/temp_\d+-//;
						$tar->extract_file( $_->{name}, $filename );
						print $filename, $/;
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

my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $worker = Gearman::Worker->new;
$worker->job_servers(@{$pcf->{GEARMAN_SERVERS}});
$worker->register_function("target", \&run_target);

$worker->work while 1;
