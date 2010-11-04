package DNALC::Pipeline::Process::Merger;

use base q(DNALC::Pipeline::Process);
use File::Spec ();
use IO::File ();
use Data::Dumper;

{
	sub new {
		my ($class, $project_dir, %params) = @_;

		my $self = __PACKAGE__->SUPER::new('MERGER', $project_dir);

		#for (keys %{$self->{conf}->{option_output_files}}) {
		#	unshift @{$self->{work_options}}, 
		#		$_, $self->{work_dir} . '/'. $self->{conf}->{option_output_files}->{$_}
		#}
		
		return $self;
	}

# 	sub get_output {
# 		my ($self, $format) = @_;
# 		$format ||= 'fasta';
	# 
# 		return unless $self->{exit_status} == 0;
# 	
# 		my $out_file;
# 		my ($out_type) = grep (/$format/i, keys %{$self->{conf}->{option_output_files}});
# 		if ($out_type) {
# 			$out_file = File::Spec->catfile($self->{work_dir}, $self->{conf}->{option_output_files}->{$out_type});
# 		}
# 		return $out_file if -e $out_file;
# 	}

	sub build_consensus {
		my ($self, $outfile, $merged_seq_file, $consensus) = @_;

		my $markup = '';
		my $data = {};
		my $align_pos = 0;

		my $ofh = IO::File->new;
		if ($ofh->open($outfile)) {
			while (my $l = <$ofh>) {
				next if $l =~ /^#/;
				next if $l =~ /^$/;
				#my ($id, $start, $seq, $end) = ;
				#if ($l =~ /^\w+/)
				if ($l !~ /^\s/) {
					my ($id, $start, $align_seq, $end) = split /\s+/, $l;
					#print "* ", scalar ($id, "\t", $align_seq), $/;
					unless ($align_pos) {
						$align_pos = index $l, $align_seq;
						#print STDERR "POS = ", $align_pos, $/;
						#print STDERR "SEQ_LEN = ", length $align_seq, $/;
					}
					#print $id, "\t", $align_seq, $/;
					$data->{$id} .= $align_seq;
				}
				else {
					chomp $l;
					$l = substr $l, $align_pos;
					$markup .= $l;
					#print "ML\t", "$l", $/;
				}
				#print $l;
			}
			$ofh->close;
		}

		#print STDERR Dumper( $data ), $/;
		my $merged_seq = '';

		my $ms_fh = IO::File->new;
		if ($ms_fh->open($merged_seq_file)) {
			while (<$ms_fh>) {
				next if />/;
				chomp;
				$merged_seq .= $_;
			}
			$ms_fh->close;
		}

		my $algn_length = length $data->{(keys %$data)[0]};
		if (0 && length($merged_seq) != $algn_length) {
			#print STDERR  "Not equal...", $/;
			my @strings = map {lc $data->{$_}} keys %$data;
			#print STDERR Dumper( \@strings), $/;

			for (my $i = 0; $i < $algn_length; $i++) {
				my ($n1, $n2) = (substr($strings[0], $i, 1),  substr($strings[1], $i, 1));
				print $n1 eq $n2
					? ' ' 
					: "$n1$n2" =~ /[n-]{2}/ 
						? '[' . substr($merged_seq, $i, 1) . ']'
						: 'x';
			}
			print STDERR $/;
			print STDERR  'len merged: ', length($merged_seq), $/;
			for (keys %$data) {
				print STDERR  "len     $_: ", length($data->{$_}), $/;
				print STDERR  $_, ':', substr($data->{$_}, 0, 50), $/;
			}
		}

		my $out_fh = IO::File->new;
		if ($out_fh->open("> $consensus")) {
			my @ids = keys %$data;
			#print $out_fh $ids[0], "\t", $data->{$ids[0]}, $/;
			#print $out_fh "M\t", $markup, "", $/;
			#print $out_fh $ids[1], "\t", $data->{$ids[1]}, $/;
			#print $out_fh "C\t", $merged_seq, $/;

			print $out_fh sprintf("%-15s", substr($ids[0], 0, 15)), ': ', uc $data->{$ids[0]}, $/;
			#print $out_fh $markup, "", $/;
			print $out_fh sprintf("%-15s", substr($ids[1], 0, 15)), ': ', uc $data->{$ids[1]}, $/;
			print $out_fh "Consensus      : ", uc $merged_seq, $/;

			$out_fh->close;
			#print length $data->{$ids[0]},  " ", length $data->{$ids[1]}, " ", length $markup, " ", length $merged_seq, $/;
		}
	}


}

1;
