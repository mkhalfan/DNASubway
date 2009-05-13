package DNALC::Pipeline::App::Utils;

use strict;
use warnings;

use Apache2::Upload;
use Data::Dumper;
use Bio::SeqIO ();

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
=head1 TODO

=item * upload


=cut

sub save_upload {
	#print STDERR "save_upload: ", Dumper( \@_), $/;
	my ($class, $args) = @_;
	my ($status, $msg, $path);

	my $r = $args->{r};
	my $param_name  = $args->{param_name};
	unless ( defined ($r) && defined ($param_name)) {
		return { status => 'fail', message => 'Invalid parameters passed!'};
	}

	my $common_name = $args->{common_name} || 'my_specie';
	my $config = DNALC::Pipeline::Config->new;

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
		my $upl_dir = $config->cf('PIPELINE')->{upload_dir};
		my $rand_s = random_string();

		$path = $upl_dir . '/' . $rand_s;
	}

	unless ($msg) {
		#my $out = IO::File->new("> $path")
		#		or die "Can't write to destination upload file [$path]: $!\n";
		#my $in = $u->fh;
		#while ( my $line = <$in> ) {
		#	print $out $line;
		#}
		#undef $out;
		#$in->close;
		my $in = Bio::SeqIO->new(-format => 'Fasta', -fh => $u->fh);
		my $fasta_seq = $in->next_seq;

		# check if file is text file..
		if ( $fasta_seq ) {
			#$status = 'ok';
			my $in  = Bio::SeqIO->new(-fh => $u->fh, -format => "Fasta");
			print STDERR  "ALPHABETU = ", $fasta_seq->alphabet, $/;
			if ($fasta_seq->alphabet eq 'dna') {
				my $max_seq_length = $config->cf('PIPELINE')->{sequence_length} || 50_000;
				# make sure the sequence is not longer then expected..
				if ($fasta_seq->length > $max_seq_length) {
					$fasta_seq->seq( uc $fasta_seq->subseq(1, $max_seq_length), 'dna' );
				}
				$fasta_seq->display_id( $common_name );
				my $out = Bio::SeqIO->new(-file => "> $path", -format => 'Fasta');
				$out->write_seq( $fasta_seq );
			}
			else {
				$status = 'fail';
				$msg = 'File content is not valid.';
			}
		}
		else {
			$status = 'fail';
			$msg = "Uploaded doesn't appear to be a text file.";
		}
	}

	return { status => $status, message => $msg, path => $path };
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
