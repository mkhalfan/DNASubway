package DNALC::Pipeline::App::Utils;

use Apache2::Upload;
use Data::Dumper;

use strict;
use warnings;
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
=head1 TODO

=item * upload


=cut

sub save_upload {
	#print STDERR "save_upload: ", Dumper( \@_), $/;
	my ($class, $r, $param_name) = @_;
	my ($status, $msg, $path);

	my $u = $r->upload($param_name);
	print STDERR  "UPL = ", $u, $/;

	unless ($u) {
		$msg = 'Upload file is missing!';
		$status = 'fail';
	}
	elsif (! _is_upload_ok($u)) {
		$msg = "Uploaded file should be a text file!";
		$status = 'fail';
	}
	else {
		my $config = DNALC::Pipeline::Config->new;
		my $upl_dir = $config->cf('PIPELINE')->{upload_dir};
		my $rand_s = random_string();

		$path = $upl_dir . '/' . $rand_s;
	}

	unless ($msg) {
		my $out = IO::File->new("> $path")
				or die "Can't write to destination upload file [$path]: $!\n";
		my $in = $u->fh;
		while ( my $line = <$in>) {
			print $out $line;
		}
		undef $out;
		$in->close;

		# check if file is text file..
		if ( -f $path && -T $path) {
			$status = 'ok';
		}
		else {
			$status = 'fail';
			$msg = "Uploaded doesn't appear to be a text file.";
		}
	}

	return { status => $status, 
			message => $msg, 
			path => $path
		};
}

sub _is_upload_ok {
	my ($u) = @_;
	my $config = DNALC::Pipeline::Config->new;
	my $mimes = $config->cf('PIPELINE')->{upload_mime_types};
	my $mt = $u->type;
	print STDERR  "Upload MIME = $mt", $/;
	my $ok = 0;

	for my $t (@{ $mimes }) {
		if ($t eq $mt) {
			$ok = 1;
			last;
		}
	}

	# TODO - check content & size
	return $ok;
}

1;
