package DNALC::Pipeline::Sample;

use strict;
use warnings;

use Carp;
use POSIX ();
use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('sample');
__PACKAGE__->columns(Primary => qw/sample_id/);
__PACKAGE__->columns(Essential => qw/organism common_name clade sequence_length/);
__PACKAGE__->columns(Other => qw/sequence_data created updated/);

__PACKAGE__->sequence('sample_sample_id_seq');

__PACKAGE__->has_many(sources => 'DNALC::Pipeline::SampleSource');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
    $_[0]->{updated} ||= $_[0]->{created};
});

__PACKAGE__->add_trigger(before_update => sub {
    $_[0]->{updated} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});



sub new {
	my ($class, $sample_id) = @_;

	my ($sample) = grep { $_->{id} == $sample_id } @{ $class->config->{samples} };
	#my $sample = __PACKAGE__->retrieve($sample_id);

	return unless $sample;

	my $sample_dir = $sample->sample_id;
	return unless -d $sample_dir  && -f $sample_dir . '/' . 'fasta.fa';

	return $sample;
	#return bless {
	#				samples_common_name => $class->config->{samples_common_name},
	#				sample_dir => $sample_dir, 
	#				sample => $sample
	#			}, $class;
}

sub config {
	my $cf = DNALC::Pipeline::Config->new;
	return $cf->('SAMPLE');
}

# sub organism {
# 	my ($self) = @_;
# 	# FIXME
# 	return $self->{sample}->{organism} if $self->{sample};
# }
# 
# sub common_name {
# 	my ($self) = @_;
# 	# FIXME
# 	return $self->{sample}->{common_name} if $self->{sample};
# }

sub sample_dir {
	my ($self) = @_;

	my $cf = $self->config;
	
	return $cf->{samples_dir} . '/' . $self->id;
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

