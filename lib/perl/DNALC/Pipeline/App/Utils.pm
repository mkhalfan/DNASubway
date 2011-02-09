package DNALC::Pipeline::App::Utils;

use strict;
use warnings;

use Apache2::Upload;
use Bio::SeqIO ();
#use Bio::Trace::ABIF ();
use File::Basename;
use IO::File ();
use Text::FixEOL ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
use Digest::MD5 ();
use Time::Piece ();
use Carp;

use Data::Dumper;

sub save_upload {
	my ($class, $args) = @_;
	my ($status, $msg, $path, $sequence_id);
	$status = 'fail';

	my $r = $args->{r};
	my $param_name  = $args->{param_name};
	unless ( defined ($r) && defined ($param_name)) {
		return { status => 'fail', message => 'Invalid parameters passed!'};
	}

	my $converted_to_dna = 0;
	my $config = DNALC::Pipeline::Config->new;

	my $u = $r->upload($param_name);
	print STDERR  "UPL = ", $u, $/;

	unless ($u) {
		$msg = 'Upload file is missing!';
	}
	elsif (! _is_upload_ok($u)) {
		$msg = "Uploaded file should be a text file!";
	}
	else {
		my $upl_dir = $config->cf('PIPELINE')->{upload_dir};

		$path = $upl_dir . '/' . random_string();
		print STDERR  "UPLOAD saved to: ", $path, $/;
		my $seq_data = '';
		my $fh = $u->fh;
		while (my $line = <$fh>) {
			$seq_data .= $line;
		}
		if ($args->{clean_sequence}) {
			if (my @ids = ($seq_data =~ m/^((?:>|;).*)/mg)) {
				$sequence_id = join "\n", @ids;
			}
			$seq_data =~ s/^(?:>|;).*//mg;
			$seq_data =~ s/(?:\d|\s)+//g;

			if ($seq_data =~ /([^actugn]+)/i) {
				$msg = "The sequence in the uploaded file contains invalid chars: [" . uc ($1) . "].";
			}
			else {
				#make it DNA
				if ($seq_data =~ tr/uU/tT/) {
					$converted_to_dna = 1;
				}

				# make it FASTA
				$seq_data = "> fasta\n" . $seq_data;
			}
		}

		my $fixer = Text::FixEOL->new;
		$seq_data = $fixer->fix_eol($seq_data);

		unless ($msg) {
			my $out = IO::File->new;
			if ($out->open($path, 'w')) {
				$status = 'success';
				print $out $seq_data;
				undef $out;
			}
			else {
				$msg = 'Unable to save uploaded file!';
			}
		}
	}
	return { status => $status, 
			message => $msg, 
			path => $path, 
			converted_to_dna => $converted_to_dna,
			sequence_id => $sequence_id
		};
}

sub save_upload_files {
	my ($class, $args) = @_;
	my ($status, $msg);
	$status = 'fail';

	unless ( defined ($args->{u}) && ref ($args->{u}) eq 'ARRAY') {
		return { status => 'fail', message => 'Invalid parameters passed!'};
	}

	my $config = DNALC::Pipeline::Config->new;
	my $upl_dir = $config->cf('PIPELINE')->{upload_dir};
	my @files = ();
	my @excluded_files = ();

	for my $u (@{$args->{u}}) {
		
		my $filename = basename($u);
		$filename =~ s/.*[\\\/]+//;

		#my $mt = $u->type;
		#print STDERR  $filename, ": ", $mt, $/;
		my $path = $upl_dir . '/' . random_string();
		print STDERR  "UPLOAD saved to: ", $path, $/;

		my $fh = $u->fh;
		#print STDERR  "text: ", -T $fh, $/;
		#print STDERR  "binary: ", -B $fh, $/;

		if (-B $fh) {
			binmode($fh);
			my $buffer = '';
			unless (seek($fh, 0, 0)) {
				carp "Error on reading file";
				return 0;
			}
			read($fh, $buffer, 4) or return do {
					$msg = "Can't read data from uploaded file!";
					push @excluded_files, { filename => $filename, msg => $msg};
					next;
				};
			$buffer = unpack('A4', $buffer);
			if ($buffer eq 'ABIF') {
				seek($fh, 0, 0);

				my $out = IO::File->new;
				if ($out->open($path, 'w')) {
					binmode $out;
					while(read($fh, $buffer, 8192)) {
						print $out $buffer;
					}
					$out->close;
				}
				push @files, { filename => $filename, type => 'trace', path => $path };
			}
			else {
				push @excluded_files, {filename => $filename, msg => 'Not a AB1 file!'};
			}

		}
		else {
			# text file

			my $in = Bio::SeqIO->new(-fh => $fh, -format => "fasta");
			unless ($in) {
				push @excluded_files, {filename => $filename, 'Unable to process file. Not a fasta file.'};
			}

			my $seq_data = '';
			my ($added, $seq_counter) = (0, 0);
			while (my $seq = $in->next_seq) {
				my $seq_name = $seq->display_id || ('seq_' . $seq_counter++);
				my $seq_alphabet = $seq->alphabet;

				#print STDERR  $args->{alphabet}, ' vs. ', $seq_alphabet, $/;
				if (defined $args->{alphabet} && $args->{alphabet} ne $seq_alphabet) {
					print STDERR  "Seq: ", $seq_name, " alphabet doesn't match the project type.", $/;
					next;
				}
				my $seq_len  = $seq->length;
				$seq_data .= ">$seq_name\n" . $seq->seq . "\n";
				$added++;
			}

			unless ($added) {
				$msg = "No $args->{alphabet} sequences found!";
			}

			unless ($msg) {
				my $out = IO::File->new;
				if ($out->open($path, 'w')) {
					print $out $seq_data;
					undef $out;
					push @files, { filename => $filename, type => 'fasta', path => $path };
				}
				else {
					$msg = 'Unable to save uploaded file!';
					push @excluded_files, {filename => $filename, msg => $msg};
				}
			}
		}
	} # end for @files

	$status = @files ? 'success' : 'fail';
	return { status => $status, 
			message => $msg, 
			files => \@files,
			excluded_files => \@excluded_files,
			converted_to_dna => 0,
		};
}

sub process_fasta_file {
	my ($class, $args) = @_;
	my $file = $args->{file} if defined $args->{file};
	my $fh = $args->{fh} if defined $args->{fh};
	my $seq_length = 0;

	my $common_name = $args->{common_name} || 'my_species';
	my $output_file = $args->{output_file};
	unless ($output_file) {
		return ('fail', 'Unable to store sequence file.');
	}

	print STDERR  "IN = file: ", $file, $/ if $file;
	print STDERR  "IN = fh: ", $/ if $fh;
	print STDERR  "OUT = ", $output_file, $/ if $file;

	my ($in, $status, $msg) = (undef, 'fail', '');
	if ($file) {
		$in = Bio::SeqIO->new(-file => $file, -format => "fasta");
	}
	elsif ($fh) {
		$in = Bio::SeqIO->new(-fh => $fh, -format => "fasta");
	}
	unless ($in) {
		return ('fail', 'Unable to process sequence file.');
	}

	my $config = DNALC::Pipeline::Config->new;

	my $crc = '';
	my $seq = $in->next_seq;
	if ($seq && $seq->alphabet eq 'dna') {
		my $max_seq_length = $config->cf('PIPELINE')->{sequence_length} || 50_000;
		# make sure the sequence is not longer then expected..

		my $fasta_seq = Bio::Seq->new( -display_id => $common_name );
		if ($seq->length > $max_seq_length) {
			$fasta_seq->seq( uc $seq->subseq(1, $max_seq_length), 'dna' );
		}
		else {
			$fasta_seq->seq( uc $seq->seq, 'dna' );
		}
		$seq_length = $fasta_seq->length;
		
		my $ctx = Digest::MD5->new;
		$ctx->add($fasta_seq->seq);
		$crc = $ctx->hexdigest;

		my $out = Bio::SeqIO->new(-file => "> $output_file", -format => 'fasta');
		$out->write_seq( $fasta_seq );
		$status = 'ok';
	}
	else {
		$status = 'fail';
		$msg = 'File content is not valid.';
	}
	
	return ($status, $msg, $crc, $seq_length);
}


sub process_input_file {
	my ($class, $file) = @_;

	unless ($file) {
		return {status => 'error', msg => 'Input file is missing!'};
	}

	print STDERR  "IN = file: ", $file, $/ if $file;

	my ($in, $status, $msg) = (undef, 'fail', '');
	if ($file) {
		$in = Bio::SeqIO->new(-file => $file, -format => "fasta");
	}
	unless ($in) {
		return {status => 'fail', msg => 'Unable to process sequence file.'};
	}

	my $config = DNALC::Pipeline::Config->new;
	my $fasta_seq;

	my $seq = $in->next_seq;
	print STDERR "ALPHABET = ", $seq->alphabet , $/;
	if ($seq && $seq->alphabet eq 'dna') {
		# make sure the sequence is not longer then maximum allowed
		my $max_seq_length = $config->cf('PIPELINE')->{sequence_length} || 50_000;

		$fasta_seq = Bio::Seq->new;
		if ($seq->length > $max_seq_length) {
			$fasta_seq->seq( uc $seq->subseq(1, $max_seq_length), 'dna' );
		}
		else {
			$fasta_seq->seq( uc $seq->seq, 'dna' );
		}
		
		$status = 'success';
	}
	else {
		$status = 'fail';
		$msg = 'File content is not valid.';
	}
	
	return { status => $status, msg => $msg, seq => $fasta_seq};
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
	unless ($ok) {
		# read file
	}

	print STDERR "is binary: ? ", -B $u->fh, $/;
	# TODO - check content & size
	return $ok;
}

sub format_datetime {
	my ($class, $time_str, $format_str, $out_format_str) = @_;
	$format_str ||= "%Y-%m-%d %H:%M:%S";
	$out_format_str ||= "%m/%d/%Y %H:%M:%S";
	my $t = Time::Piece->strptime($time_str, $format_str);
	
	return $t->strftime($out_format_str);
}

sub remove_dir {
	my ($class, $dir, $keep_root) = @_;

	if (-d $dir) {
		my @dir_content = <$dir/*>;
		foreach my $of (@dir_content) {
			if ( -d $of) {
				$class->remove_dir($of);
			}
			else {
				unlink $of;
			} 
		}
		rmdir $dir unless $keep_root;
	}
}

1;
