#
#===============================================================================
#
#         FILE:  Sample.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban (), ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor
#      VERSION:  1.0
#      CREATED:  05/29/09 10:38:31
#     REVISION:  ---
#===============================================================================

package DNALC::Pipeline::Sample;

use DNALC::Pipeline::Config ();
use strict;
use Carp;

sub new {
	my ($class, $sample_id) = @_;

	my $cf = DNALC::Pipeline::Config->new;
	my $pcf = $cf->cf('PIPELINE');
	my ($sample) = grep { $_->{id} == $sample_id } @{ $pcf->{samples} };

	return unless $sample;
	my $sample_dir = $pcf->{samples_dir} . '/' . $sample_id;
	
	return unless -d $sample_dir  && -f $sample_dir . '/' . 'fasta.fa';

	return bless {
					samples_common_name => $pcf->{samples_common_name},
					sample_dir => $sample_dir, 
					sample => $sample
				}, $class;
}

sub organism {
	my $self = shift;
	return $self->{sample}->{organism} if $self->{sample};
}

sub common_name {
	my $self = shift;
	return $self->{sample}->{common_name} if $self->{sample};
}

sub copy_results {
	my ($self, $args) = @_;

	return unless defined $args && 'HASH' eq ref $args;

	my $routine = $args->{routine};
	my $project_id = $args->{project_id};
	my $project_dir = $args->{project_dir};
	my $common_name = $args->{common_name} || $self->common_name;

	my $cf = DNALC::Pipeline::Config->new;
	my $rcf = $cf->cf(uc $routine);
	unless ($rcf) {
		carp "Sample::copy_results: routine $routine is undefined\n";
		return;
	}
	unless (-d $project_dir) {
		carp "Sample::copy_results: destination directory $project_dir is missing\n";
		return;
	}
	unless (defined $project_id && $project_id ) {
		carp "Sample::copy_results: project_id is missing\n";
		return;
	}

	unless (defined $common_name && $common_name ) {
		carp "Sample::copy_results: Species name is missing\n";
		return;
	}
	# remove spaces
	$common_name =~ s/\s+/_/g;
	$common_name =~ s/-/_/g;
	$common_name .= '_' . $project_id;

	my $routine_dir = $project_dir . '/' . uc $routine;
	unless (-d $routine_dir) {
		my $rc = mkdir $routine_dir;
		unless ($rc) {
			carp "Sample::copy_results: unable to create routine directory: ", $!, $/;
			return;
		}
	}

	my $sample_gff_file = $self->{sample_dir} . '/' . uc ($routine) . '/' . $rcf->{gff3_file};
	unless (-f $sample_gff_file) {
		print STDERR  "SAMPLE GFF is missing for: ", $routine, $/;
		return;
	}
	my $out_gff_file = $routine_dir . '/' . $rcf->{gff3_file};
	print STDERR  "GFF file for $routine = ", $sample_gff_file, $/;
	print STDERR  "GFF out file for $routine = ", $out_gff_file, $/;

	my $in = IO::File->new;
	my $out = IO::File->new;
	if ($in->open($sample_gff_file, 'r') && $out->open($out_gff_file, 'w')) {
		while (<$in>) {
			$_ =~ s/$self->{samples_common_name}/$common_name/g;
			print $out $_;
		}
		undef $out;
		undef $in;
	}
	else {
		return; #not ok
	}
	
	return 1; #ok
}

sub copy_fasta {
	my ($self, $args) = @_;

	return unless defined $args && 'HASH' eq ref $args;

	my $project_dir = $args->{project_dir};
	my $project_id = $args->{project_id};
	my $common_name = $args->{common_name} || $self->common_name;
	my $masker = $args->{masker};

	unless (-d $project_dir) {
		carp "Sample::copy_fasta: destination directory $project_dir is missing\n";
		return;
	}
	unless (defined $project_id && $project_id ) {
		carp "Sample::copy_fasta: project_id is missing\n";
		return;
	}
	unless (defined $common_name && $common_name ) {
		carp "Sample::copy_fasta: Species name is missing\n";
		return;
	}
	# remove spaces
	$common_name =~ s/\s+/_/g;
	$common_name =~ s/-/_/g;
	$common_name .= '_' . $project_id;

	my $sample_fasta = $self->{sample_dir} . '/fasta.fa';
	my $out_fasta = $project_dir . '/fasta.fa';
	if (defined $masker && $masker) {
		my $masker_dir = $project_dir . '/' . uc $masker;
		foreach my $dir ($masker_dir, "$masker_dir/output") {
			unless (-d $dir) {
				my $rc = mkdir $dir;
				unless ($rc) {
					carp "Sample::copy_masked_fasta: unable to create masked directory: ", $!, $/;
					return;
				}
			}
		}

		$sample_fasta = $self->{sample_dir} . '/' . uc ($masker) . '/output/fasta.fa.masked';
		$out_fasta = $masker_dir . '/output/fasta.fa.masked';
	}
	print STDERR  "Fasta sample = ", $sample_fasta, $/;
	print STDERR  "Fasta output = ", $out_fasta, $/;

	my $in = IO::File->new;
	my $out = IO::File->new;
	if ($in->open($sample_fasta, 'r') && $out->open($out_fasta, 'w')) {
		while (<$in>) {
			$_ =~ s/^>$self->{samples_common_name}/>$common_name/;
			print $out $_;
		}
		undef $out;
		undef $in;
	}
	else {
		return; #not ok
	}
	
	return 1; #ok
}
1;

