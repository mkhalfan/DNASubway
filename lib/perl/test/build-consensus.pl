#!/usr/bin/perl 

use common::sense;
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::App::Utils ();
use Bio::AlignIO ();
use IO::File;
use Data::Dumper;

#-----------------------------------------------------
sub build_consensus {
	my ($outfile, $merged_seq_file, $consensus, $pairnum) = @_;

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
					print "POS = ", $align_pos, $/;
					print "SEQ_LEN = ", length $align_seq, $/;
				}
				print $id, "\t", $align_seq, $/;
				$data->{$id} .= $align_seq;
			}
			else {
				chomp $l;
				$l = substr $l, $align_pos;
				#$data->{markup} .= $l;
				$markup .= $l;
				print "ML\t", "$l", $/;
			}
			#print $l;
		}
		$ofh->close;
	}

	print STDERR Dumper( $data ), $/;
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
	
	my $out_fh = IO::File->new;
	if ($out_fh->open("> $consensus")) {
		my @ids = keys %$data;
		print $out_fh $ids[0], "\t", $data->{$ids[0]}, $/;
		print $out_fh "M\t", $markup, "", $/;
		print $out_fh $ids[1], "\t", $data->{$ids[1]}, $/;
		print $out_fh "C\t", $merged_seq, $/;
		$out_fh->close;
		print length $data->{$ids[0]},  " ", length $data->{$ids[1]}, " ", length $markup, " ", length $merged_seq, $/;
	}
}


#-----------------------------------------------------

my $data = [{
            'pair' => '0',
            'ch' => 1,
            'id' => '01.fasta'
          },{
            'pair' => '0',
            'ch' => 0,
            'id' => '02.fasta'
          },{
            'pair' => '1',
            'ch' => 0,
            'id' => '03.fasta'
          },{
            'pair' => '1',
            'ch' => 1,
            'id' => '04.fasta'
          }];

my $gcf = DNALC::Pipeline::Config->new->cf("GREENLINE");
my $dir = $gcf->{PROJECTS_DIR} . '/fasta';

my $work_dir = $dir . '/pwalign';

my @pairs = ();
for my $item (@$data) {
	my $pair = $item->{pair};
	my $seq_file = $item->{id};
	$seq_file =~ s/\///g;
	$seq_file = $dir . '/' . $seq_file;

	if (-f $seq_file && $pair =~ /^\d+$/) {
		if (defined $pairs[$pair]) {
			push @{$pairs[$pair]}, {seq => $seq_file, rc => $item->{ch}};
		}
		else {
			$pairs[$pair] = [{seq => $seq_file, rc => $item->{ch}}];
		}
	}
}

print STDERR Dumper( \@pairs ), $/;
#DNALC::Pipeline::App::Utils->remove_dir($work_dir);
#mkdir $work_dir;

my $pair_cnt = 1;
for my $pair (@pairs) {
	next unless ('ARRAY' eq ref ($pair) && scalar @$pair == 2);
	#print $pair, $/;
	my @args = ();
	my @n_args = ();
	my @to_reverse = ();
	my $cnt = 1;
	for my $item (@$pair) {
		push @args, $item->{seq};
		push @to_reverse, "-sreverse$cnt" if $item->{rc};
		$cnt++;
	}
	#my $n_outfile = $work_dir . "/n_outfile_$pair_cnt.txt";
	my $outfile = $work_dir . "/outfile_$pair_cnt.txt";
	my $merged_seq_file = $work_dir . "/merged_seq_$pair_cnt.txt";
	push @args, @to_reverse;
	push @args, (
			'-auto',
			'-gapopen', '10.0',
			'-gapextend', '0.5',
			'-outfile', $outfile,
			'-outseq', $merged_seq_file
		);
	#push @n_args, @args;
	#pop @n_args;
	#splice @n_args, $#n_args - 1, 2;

	print "@n_args", $/;
	my $rc = system ('/usr/local/bin/merger', @args);
	print STDERR  "RC = $rc @ pair $pair_cnt", $/ if $rc;

	my $consensus_file = $work_dir . "/processed_concessus_$pair_cnt.txt";
	build_consensus($outfile, $merged_seq_file, $consensus_file);
	$pair_cnt++;
	#last;
}
#build_consensus("/var/www/vhosts/pipeline.dnalc.org/var/projects/greenline/fasta/pwalign/outfile_1.txt",
#				"/var/www/vhosts/pipeline.dnalc.org/var/projects/greenline/fasta/pwalign/consensus_1.txt",
#				"/var/www/vhosts/pipeline.dnalc.org/var/projects/greenline/fasta/pwalign/processed_concessus_1.txt",
#				2
#			);



