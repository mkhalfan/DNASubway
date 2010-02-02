package DNALC::Pipeline::App::ProjectManager;

use common::sense;

use File::Path;
use File::Copy qw/move/;
use Carp;

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::ProjectLogger ();
use DNALC::Pipeline::Chado::Utils ();
use Bio::SeqIO ();
use Data::Dumper; 

#-----------------------------------------------------------------------------
sub new {
	my ($class, $project) = @_;

	my $self = bless {
					config => DNALC::Pipeline::Config->new->cf('PIPELINE'),
					logger => DNALC::Pipeline::ProjectLogger->new,
				}, __PACKAGE__;
	if ($project) {
		if (ref $project eq '' && $project =~ /^\d+$/) {
			my $proj = DNALC::Pipeline::Project->retrieve($project);
			unless ($proj) {
				print STDERR  "Project with id=$project wasn't found!", $/;
			}
			else {
				$self->project($proj);
			}
		}
		else { # we assume it's an instance of a project
			$self->project($project);
		}
	}

	$self;
}

#-----------------------------------------------------------------------------
sub search {
	my ($self, %args) = @_;

	DNALC::Pipeline::Project->search(%args);
}
#-----------------------------------------------------------------------------
sub config {
	my ($self) = @_;

	$self->{config};
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

	my $proj = DNALC::Pipeline::Project->search(user_id => $user_id, name => $name);
	if ($proj) {
		return {status => 'fail', msg => "There is already a project named \"$name\"."};
	}
	# create project
	$proj = eval { DNALC::Pipeline::Project->create({
						user_id => $user_id,
						name => $name,
						organism => $organism,
						common_name => $common_name,
						sample => $sample,
						clade => $clade,
						sequence_length => $seq_length,
						crc => $crc,
						description => $params->{description},
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
	$seq->display_id($self->cleaned_common_name);

	my $fasta_file = $self->work_dir . '/fasta.fa';
	my $out = Bio::SeqIO->new(-file => "> $fasta_file", -format => 'Fasta');
	$out->write_seq( $seq );
	
	my $rc = $self->init_chado;

	unless ($rc) {
		$proj->delete;
		return {status => 'fail', msg => "Unable to initialize the project!"};
	}

	return {status => 'success', msg => $msg};
}

#-----------------------------------------------------------------------------
sub add_evidence {
	my ($self, $r, $type) = @_;
	unless ($type =~ /^evid_(?:nt|prot)$/) {
		return {status => 'fail', message => 'Invalid params.'}
	}
	unless ($r->upload($type)) {
		return {status => 'fail', message => 'Missing the upload file.'}
	}
	my @errors = ();
	my $filepath;
	my $evidence_dir;

	my $st = DNALC::Pipeline::App::Utils->save_upload( { r => $r, param_name => $type});
	#print STDERR Dumper( $st), $/;

	if ($st->{status} eq 'fail') {
		print STDERR  'PM: __add_evidence__:', $st->{message}, $/;
		push @errors, "Unable to upload file: ". $st->{message};
	}
	else {
		$filepath = $st->{path};

		$evidence_dir = $self->evidence_dir;
		eval { mkpath( $evidence_dir ) };
		if ($@) {
			push @errors, "Couldn't create $evidence_dir: $@", $/;
		}
	}

	unless (@errors) {
		# set the workflow history
		#my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $self->project );
		#if ($self->fasta_file) {
		#	$wfm->set_status('upload_fasta','Done');
		#}

		my $file = $evidence_dir . '/' . $type;
		move $filepath, $file;

		my $ftype = $type eq 'evid_nt' ? 'F' : 'T';
		my $cmd = "/usr/bin/formatdb -i $file -p $ftype -o T -l $file" . '_log.txt 2>/dev/null';
		print STDERR  "CMD: ", $cmd, $/;
		if (system($cmd) == 0) {
			print STDERR  "Format DB = success for ", $type, $/;
			return {status => 'success'};
		}
		else {
			print STDERR  "Error formatting the DB: ", $type, $/;
			push @errors, "Error formatting the evidence DB.";
		};
	}
	return {status => 'fail', message => join(' ', @errors)}
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
sub cleaned_common_name {
	my ($self) = @_;
	
	my $common_name = $self->project->common_name;
	$common_name =~ tr/A-Z/a-z/;
	$common_name =~ s/[-\s]+/_/g;
	$common_name .= '_' . $self->project->id;

	$common_name;
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
sub evidence_dir {
	my ($self) = @_;

	return $self->work_dir . '/evidence';
}#-----------------------------------------------------------------------------
sub work_dir {
	my ($self) = @_;
	return unless ref $self eq __PACKAGE__;
	my $proj = $self->project;
	unless ($proj)  {
		confess "Project is missing...\n";
	}

	return $self->config->{project_dir} . '/' . sprintf("%04X", $proj->id);
}

#-----------------------------------------------------------------------------
sub username {
	my ($self) = @_;
	unless ($self->{username}) {
		my $u = DNALC::Pipeline::User->retrieve($self->project->user_id);
		$self->{username} = $u ? $u->username : '';
	}
	$self->{username};
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

	my $path = $self->work_dir;
	return unless $path;

	eval { mkpath($path) };
	if ($@) {
		print STDERR "Couldn't create $path: $@", $/;
		return;
	}
	return 1;
}
#-----------------------------------------------------------------------------

sub init_chado {
	my ($self) = @_;

	unless (ref $self) {
		confess "Improper use of init_chado()\n";
		return;
	}

	my $project  = $self->project;
	unless ($project) {
		confess "init_chado: Project is missing.\n";
		return;
	}
	my $organism_str = join('_', split /\s+/, $project->organism)
						. '_' . $project->common_name;

	my $cutils = DNALC::Pipeline::Chado::Utils->new(
					username => $self->username,
					dumppath => $self->config->{GMOD_DUMPFILE},
					profile => $self->config->{GMOD_PROFILE},
					organism_string => $organism_str,
					gbrowse_template => $self->config->{GBROWSE_TEMPLATE},
					gbrowse_confdir  => $self->config->{GBROWSE_CONF_DIR},
				);
	eval {
		$cutils->create_db(1);
	};
	if ($@)  {
		print STDERR  "create_db: ", $@, $/;
	}

	#unless ($cutils->check_db_exists( $self->username)) {
	#	print STDERR  "Unable to create CHADO DB for ", $self->username, $/;
	#	return;
	#}
	my $conffile_ok = $cutils->gmod_conf_file( $project->id );
	print STDERR "Created CHADO CONF file = ", $conffile_ok, $/;

	# read data from new file
	$cutils->profile($self->chado_user_profile);
	unless ($cutils->insert_organism) {
		# failed...
		return;
	}
	
	return $cutils->load_fasta($self->fasta_file);
}
#-----------------------------------------------------------------------------
sub chado_user_profile {
	my ($self) = @_;
	
	sprintf("%s_%d", $self->username, $self->project->id);
}
#-----------------------------------------------------------------------------
sub get_gff3_file {
	my ($self, $routine) = @_;
	
	unless ($routine) {
		print STDERR  "ProjectManager->get_gff3_file: routine is missing!!", $/;
		return;
	}
	$routine = uc $routine;
	my $dir = $self->work_dir . '/' . $routine;
	return unless -d $dir;

	my $config = DNALC::Pipeline::Config->new;
	my $file = $dir . '/' . $config->cf($routine)->{gff3_file};
	#print STDERR  "GFF3 for {$routine} = ", $file, $/;
	return $file if -f $file;
}
#-----------------------------------------------------------------------------

sub fasta_masked_nolow {
	my ($self) = @_;
	my $ff = $self->work_dir . '/REPEAT_MASKER2/output/fasta.fa.masked';
	return $self->fasta_file unless -e $ff;
	return $ff;
}
#-----------------------------------------------------------------------------

sub fasta_masked_xsmall {
	my ($self) = @_;
	my $ff = $self->work_dir . '/REPEAT_MASKER/output/fasta.fa.masked';
	return $self->fasta_file unless -e $ff;
	return $ff;
}
#-----------------------------------------------------------------------------
sub get_available_gff3_files {
	my ($self) = @_;

	my @files = ();
	my $config = DNALC::Pipeline::Config->new;
	my $routines = $config->cf('PIPELINE')->{enabled_routines} || [];

	for my $routine (@$routines) {
		my $f = $self->get_gff3_file($routine);
		#print STDERR  $routine, "->", $f, $/;
		push @files, $f if defined ($f) &&  -f $f;
	}
	return \@files;
}
#-----------------------------------------------------------------------------
sub get_organism_conflicts {
	my ($self, $params) = @_;
	my @orgs = DNALC::Pipeline::Project->get_used_organisms($params);
	my @sample_orgs = DNALC::Pipeline::Sample->get_organisms;
	my @conflicts = ();
	my %uniq_orgs = ();
	%uniq_orgs = map { 
						$_->{organism} => $_->{common_name} unless exists $uniq_orgs{organism}
					} (@orgs, @sample_orgs);
	for my $organism (keys %uniq_orgs) {
		my $common_name = $uniq_orgs{$organism};
		if (($organism ne $params->{organism} && $common_name eq $params->{common_name})
				|| 
			($organism eq $params->{organism} && $common_name ne $params->{common_name}))
		{
				push @conflicts, {organism => $organism , common_name => $common_name};
		}
	}
	\@conflicts;
}
#-----------------------------------------------------------------------------
sub log {
	my ($self, $message, %args) = @_;
	my $type = defined $args{type} && $args{type} ? $args{type} : 'INFO';

	my $logger = $self->{logger};
	my $proj = $self->project;
	my $user_id = defined $args{user_id} && $args{user_id} 
					? $args{user_id} 
					: $proj->user_id;
	
	eval { $logger -> log(
				user_id => $user_id,
				project_id => $proj->id,
				type => $type,
				message => $message
			);
		};
	if ($@) {
		print STDERR  "Logger: ", $@, $/;
	}
}
#-----------------------------------------------------------------------------
sub latest_log_entries {
	my ($self) = @_;
	return $self->{logger}->search_latest($self->project->id);
}
#-----------------------------------------------------------------------------
sub all_log_entries {
	my ($self) = @_;
	return $self->{logger}->search_all($self->project->id);
}

#-----------------------------------------------------------------------------
sub remove_project {
	my ($self) = @_;
	my $p = $self->project;
	my $organism_str = join('_', split /\s+/, $p->organism) . '_' . $p->common_name;

	my $cutils = eval {
				DNALC::Pipeline::Chado::Utils->new(
					username => $self->username,
					organism_string => $organism_str,
					profile => $self->chado_user_profile,
					gbrowse_template => $self->config->{GBROWSE_TEMPLATE},
					gbrowse_confdir  => $self->config->{GBROWSE_CONF_DIR},
				);
			};
	if ($@) {
		print STDERR  "Unable to process project $p: ", $@, $/;
	}
	else {
		my $gmod_conf_file = $cutils->gmod_conf_file($p->id);
		#print STDERR  "p.$p ->", $gmod_conf_file, $/;

		my $gbrowse_file = $cutils->gbrowse_chado_conf($p->id);
		#print STDERR  "p.$p =>", $gbrowse_file , $/;

		unlink $gmod_conf_file, $gbrowse_file;
	}

	# project dir
	my $dir = $self->work_dir;
	#print STDERR  "p.$p DIR => ", $dir, $/;
	DNALC::Pipeline::App::Utils->remove_dir($dir);
	$p->delete;
}
#-----------------------------------------------------------------------------
1;
