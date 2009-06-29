package DNALC::Pipeline::ProjectManager;

use strict;
use warnings;

use File::Path;
use Carp;

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();

#-----------------------------------------------------------------------------
sub new {
	my ($class, $pid)	 = @_;

	my $self = bless {}, __PACKAGE__;
	if ($pid) {
		my $project = DNALC::Pipeline::Project->retrieve($pid);
		unless ($project) {
			print STDERR  "Project $pid not found!", $/;
		}
		else {
			$self->project($project);
		}
	}

	$self;
}

#-----------------------------------------------------------------------------

sub create_project {
	my ($self, $params) = @_;

	my ($status, $msg) = ('fail', '');
	my $seq = $params->{seq};
	unless ('Bio::Seq' eq ref $seq) {
		$msg = "Invalid param [seq]. Expecting 'Bio::Seq' object, got: " . $seq;
		print STDERR  $msg, $/;
		return {status => 'fail', msg => $msg};
	}
	my $common_name = $params->{common_name};
	my $organism = $params->{organism};
	my $clade = $params->{clade} || 'u';
	my $name = $params->{name};
	my $user_id = $params->{user_id};
	my $sample = $params->{sample};

	my $seq_length = $seq->length;
	my $crc = $self->compute_crc($seq);

	# create project
	my $proj = eval { DNALC::Pipeline::Project->create({
						user_id => $user_id,
						name => $name,
						organism => $organism,
						common_name => $common_name,
						sample => $sample,
						clade => $clade,
						sequence_length => $seq_length,
						crc => $crc,
				});
	};
	if ($@) {
		$msg = "Error creating the project: $@";
		print STDERR  $msg, $/;
		return {status => 'fail', msg => $msg};
	}
	print STDERR  "NEW PID = ", $proj, $/;

	$self->project($proj);

	# create folder
	if ($self->create_work_dir) {
		print STDERR "project's work_dir: ", $self->work_dir, $/;
	}
	else {
		$msg = "Failed to create work_dir for project [$proj]";
		print STDERR  $msg, $/;
	}

	# write fasta file
	$common_name =~ tr/A-Z/a-z/;
	$common_name =~ s/[-\s]+/_/g;
	#$common_name =~ s/-/_/g;

	$seq->display_id($common_name);

	my $fasta_file = $self->work_dir . '/fasta.fa';
	my $out = Bio::SeqIO->new(-file => "> $fasta_file", -format => 'Fasta');
	$out->write_seq( $seq );

	$self->create_gbrowse_config;

	return {status => 'success', msg => $msg};
}

#-----------------------------------------------------------------------------
sub project {
	my ($self, $project) = @_;
	
	if ($project) {
		$self->{project} = $project;
	}

	$self->{project};
}

#-----------------------------------------------------------------------------
sub compute_crc {
	my ($self, $seq) = @_;

	return unless $seq;
	
	my $ctx = Digest::MD5->new;
	$ctx->add($seq->seq);
	$ctx->hexdigest;
}

#-----------------------------------------------------------------------------
sub work_dir {
	my ($self) = @_;
	return unless ref $self eq __PACKAGE__;
	my $proj = $self->project;
	unless ($proj)  {
		confess "Project is missing...\n";
	}

	my $config = DNALC::Pipeline::Config->new->cf('PIPELINE');
	return $config->{project_dir} . '/' . sprintf("%04X", $proj->id);
}

#-----------------------------------------------------------------------------
sub username {
	my ($self) = @_;
	my $u = DNALC::Pipeline::User->retrieve($self->project->user_id);
	return $u ? $u->username : '';
}
#-----------------------------------------------------------------------------

sub fasta_file {
	my ($self) = @_;
	
	my $ff = $self->work_dir . '/fasta.fa';
	return $ff if -e $ff;
}

#-----------------------------------------------------------------------------

sub create_work_dir {
	my ($self) = @_;

	my $proj = $self->project;
	unless ($proj) {
		print STDERR  "Trying to create work directory for undef project..", $/;
		return;
	}

	my $path = $proj->work_dir;
	return unless $path;

	eval { mkpath($path) };
	if ($@) {
		print STDERR "Couldn't create $path: $@", $/;
		return;
	}
	return 1;
}
#-----------------------------------------------------------------------------

sub create_gbrowse_config {
	print STDERR  "\n => should create GBrowse config file..\n", $/;
}
#-----------------------------------------------------------------------------

1;
