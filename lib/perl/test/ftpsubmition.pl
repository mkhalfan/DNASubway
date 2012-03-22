
use Net::FTP ();
use DNALC::Pipeline::Config ();
use File::Basename qw/basename/;
use Data::Dumper;

use strict;
use warnings;

sub submit {
	my ($file) = @_;

	my $cf = DNALC::Pipeline::Config->new->cf('PHYLOGENETICS');

	my $user = $cf->{GB_FTP_USER},
	my $pw = $cf->{GB_FTP_PW},
	
	my $ftp = Net::FTP->new($cf->{GB_FTP_HOST}, Debug => 0)
		or do {
			return {status => 'error', 'message' => "Cannot connect to: $cf->{GB_FTP_HOST}: $@" };
		};

	$ftp->login($user, $pw) or do {
			return {status => 'error', 'message' => "Cannot login (ftp): " . $ftp->message };
		};

	$ftp->binary;
	$ftp->put($file) or do {
				$ftp->quit;
				return {status => 'error', 'message' => "ftp put failed: " . $ftp->message };
		};

	my $msg = $ftp->message || 'No mesage';

	my $fname = basename($file);

	my ($info) = grep /$fname/, $ftp->dir;
	print STDERR '**: ', $info, $/;


	$ftp->quit;			
	return {status => 'success', 'message' => $msg};
}

my $st = submit('/tmp/ftptry42.tar');
print STDERR Dumper( $st ), $/;
