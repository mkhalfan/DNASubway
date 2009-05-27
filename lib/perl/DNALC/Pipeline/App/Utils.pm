package DNALC::Pipeline::App::Utils;

use strict;
use warnings;

use Apache2::Upload;
use Data::Dumper;
use Bio::SeqIO ();

use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);

use Digest::MD5 ();
use Time::Piece ();

=head1 TODO

=item * upload


=cut

sub save_upload {
	#print STDERR "save_upload: ", Dumper( \@_), $/;
	my ($class, $args) = @_;
	my ($status, $msg, $path, $crc);

	my $r = $args->{r};
	my $param_name  = $args->{param_name};
	unless ( defined ($r) && defined ($param_name)) {
		return { status => 'fail', message => 'Invalid parameters passed!'};
	}

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

	# check/fix content 
	unless ($msg) {
		($status, $msg, $crc) = $class->process_fasta_file({
					fh => $u->fh,
					common_name => $args->{common_name},
					output_file => $path,
				});
	}

	return { status => $status, message => $msg, path => $path, crc => $crc };
}

sub process_fasta_file {
	my ($class, $args) = @_;
	my $file = $args->{file} if defined $args->{file};
	my $fh = $args->{fh} if defined $args->{fh};

	my $common_name = $args->{common_name} || 'my_specie';
	my $output_file = $args->{output_file};;
	unless ($output_file) {
		return ('fail', 'Unable to store sequence file.');
	}

	print STDERR  "IN = file: ", $file, $/ if $file;
	print STDERR  "IN = fh: ", $/ if $fh;
	print STDERR  "OUT = ", $output_file, $/ if $file;

	my ($in, $status, $msg) = (undef, 'fail', '');
	if ($file) {
		$in = Bio::SeqIO->new(-file => $file, -format => "Fasta");
	}
	elsif ($fh) {
		$in = Bio::SeqIO->new(-fh => $fh, -format => "Fasta");
	}
	unless ($in) {
		return ('fail', 'Unable to process sequence file.');
	}

	my $config = DNALC::Pipeline::Config->new;

	my $crc => '';
	my $fasta_seq = $in->next_seq;
	#print STDERR  "ALPHABETU = ", $fasta_seq->alphabet, $/;
	if ($fasta_seq && $fasta_seq->alphabet eq 'dna') {
		my $max_seq_length = $config->cf('PIPELINE')->{sequence_length} || 50_000;
		# make sure the sequence is not longer then expected..
		if ($fasta_seq->length > $max_seq_length) {
			$fasta_seq->seq( uc $fasta_seq->subseq(1, $max_seq_length), 'dna' );
		}
		$fasta_seq->display_id( $common_name );
		
		my $ctx = Digest::MD5->new;
		$ctx->add($fasta_seq->seq);
		$crc = $ctx->hexdigest;

		my $out = Bio::SeqIO->new(-file => "> $output_file", -format => 'Fasta');
		$out->write_seq( $fasta_seq );
		$status = 'ok';
	}
	else {
		$status = 'fail';
		$msg = 'File content is not valid.';
	}
	
	return ($status, $msg, $crc);
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

sub format_datetime {
	my ($class, $time_str, $format_str) = @_;
	$format_str ||= "%Y-%m-%d %H:%M:%S";
	my $t = Time::Piece->strptime($time_str, $format_str);
	
	return $t->strftime("%m/%d/%Y %H:%M:%S");
}

1;
