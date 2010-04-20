#!/usr/bin/perl 

use strict;
use warnings;

use Archive::Tar;
use File::Basename;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;
use DNALC::Pipeline::TargetProject ();
use DNALC::Pipeline::Config();

use Gearman::Client ();
use Time::HiRes qw(gettimeofday tv_interval);

my $tpid = 70;
my $client = Gearman::Client->new;
my $sx = $client->job_servers('127.0.0.1');

my $tp = DNALC::Pipeline::TargetProject->retrieve($tpid);

print STDERR $tp->work_dir, $/;

my $cf = DNALC::Pipeline::Config->new->cf('TARGET');
my $ua = LWP::UserAgent->new;
$ua->agent("dnasubway.org");

my $res;
my $server = $cf->{TARGET_SERVER};
#my $post_url = $server . $cf->{DNA_URL};
#my $post_url = $server . '/ap_TARGeT_dna_v2.php';
my $post_url = $server . '/ap_TARGeT_dna.php';
#my $post_url = $server . '/ap_TARGeT_protein_v4.php';
#my $post_url = $server . '/ap_TARGeT_dna.php';

my $seq = $tp->seq;
my @genomes = map {$_->genome_id->id} $tp->genomes;
my %genomes = map {my $o = $_->genome_id->organism; $o =~ s/\s+/_/g;$_->genome_id->id => $o} $tp->genomes;

print STDERR Dumper( \%genomes ), $/;

#push @genomes, ("Gm_pz5", 'Rc_pz5', 'Pp_pz5', 'Osj_pz5', 'Bd_pz5', 'Sb1');
#@genomes = ('Rc_pz5');

my $query = {
	'orgn[]' => \@genomes,
	'_querys_0' => $seq,
	'submit' => 'Tree',
};

#print STDERR Dumper( $query ), $/;

my $xml_url = $server . '/Visitors/143_48_90_149/temp_041982502.xml';
#my $xml_url = $server . '/Visitors/143_48_90_149/temp_041994310.xml';

#----------------------------------------------------------------
my $archive = '';

unless ($xml_url) {
	my $t0 = [gettimeofday];
	$res = $ua->post($post_url, $query);
	unless ($res->is_success) {
		print $res->status_line, "\n";
	}
	else {
		my $html = $res->content;
		print "[$html]", $/;

		if ($html =~ /(\/Visitors.*\.xml)/s) {
			print $1, $/;
			$xml_url = $server . $1;
		}
	}
	print STDERR "elapsed = ", tv_interval ( $t0 ), $/;
}


if ($xml_url) {
	#print $xml_url, $/;
	my $t0 = [gettimeofday];
	$res = $ua->get($xml_url);
	print STDERR "elapsed time for XML = ", tv_interval ( $t0 ), $/;
	unless ($res->is_success) {
		print $res->status_line, "\n";
		$tp->status('failed');
	}
	else {
		my @files = ();
		my $work_dir = $tp->work_dir;

		my $xml_str = $res->content;
		my $ref = XMLin($xml_str);
		my $steps = $ref->{run}->{steps}->{step};
		if ($ref->{run}->{other} && $ref->{run}->{other}->{archive}) {
			#print $ref->{run}->{other}, $/;
			#print $ref->{run}->{other}->{archive}, $/;
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

		#print STDERR  "Files = ", Dumper(\@files), $/, $/;

		if (@files) {
			$tp->create_work_dir;

			push @files, $archive if $archive;

			$tp->create_work_dir;
			my $work_dir = $tp->work_dir;
			for (@files) {
				$_ =~ s{^\./}{/};
				my $file_url = $server . $_;
				print STDERR 'GET: ', $file_url, $/;
				my ($ext) = ($_ =~ /\.(\w{2,5})$/);
				$ext ||= 'dat';

				$t0 = [gettimeofday];
				$res = $ua->get( $file_url );				
				print STDERR "\telapsed time for $_ = ", tv_interval ( $t0 ), $/, $/;

				unless ($res->is_success) {
					print STDERR 'Err: ', $res->status_line, "for file: ", $file_url, "\n";
				}
				else {
					my $content = $res->content;
					my $file = $work_dir . '/file.' . $ext;
					my $fh = IO::File->new;
					if ($fh->open( $file , 'w')) {
						if ($ext eq 'nw') {
							print STDERR  $content, $/, $/;
							#$content =~ s/([a-z0-9]+)_AS_/$genomes{$1} . '_AS_'/gei;
							#$content =~ s/(\d+)_([A-Z][a-z0-9_]+):0/$1.'_'.$genomes{$2} .'-<' .$tpid . '>:0'/gei;
							$content =~ s/(\d+)_([A-Z][a-z0-9_]+):0/$2-$1-$tpid:0/gi;

							#print STDERR  "<< $1 >>", $/;
							print STDERR  $content, $/;
						}
						elsif ($ext eq 'fasta') {
							#$content =~ s/^>([a-z0-9]+)_AS_/'>' . $genomes{$1} . '_AS_'/mgei;
							$content =~ s/^>(\d+)_([A-Z][a-z0-9_]+)/>$2-$1-$tpid/mgi;
						}
						$fh->binmode if $ext =~ /gz|jpg/i;
						print $fh $content;
						$fh->close;

						if ($ext eq 'gz') {
							$archive = $file;
						}
					}
					else {
						print STDERR  "Unable to write in ", $file, $/;
					}
					#print STDERR  $file, $/;
				}
			}
			#print STDERR  "ARCHIVE: ", $archive, $/;
			if ($archive && -f $archive && Archive::Tar->can_handle_compressed_files)
			{
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
	$tp->update;
}

