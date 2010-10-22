package DNALC::Pipeline::App::Phylogenetics::ProjectManager;


use common::sense;

use Fcntl qw/:flock/;
use IO::File ();
use File::Basename;
use File::Path;
use File::Spec;
use File::Copy qw/move/;
use File::Slurp qw/slurp/;
use Carp;
use Data::Dumper;

#use DNALC::Pipeline::ProjectLogger ();
use DNALC::Pipeline::Config ();
use aliased 'DNALC::Pipeline::Phylogenetics::Project';
use aliased 'DNALC::Pipeline::Phylogenetics::DataSource';
use aliased 'DNALC::Pipeline::Phylogenetics::DataFile';
use aliased 'DNALC::Pipeline::Phylogenetics::DataSequence';
use aliased 'DNALC::Pipeline::Phylogenetics::Pair';
use aliased 'DNALC::Pipeline::Phylogenetics::PairSequence';
use DNALC::Pipeline::Process::Merger ();
use DNALC::Pipeline::Process::Muscle();

use Bio::SeqIO ();
use Bio::AlignIO ();
use Bio::Trace::ABIF ();

#-----------------------------------------------------------------------------
sub new {
	my ($class, $project) = @_;

	my $self = bless {
			config => DNALC::Pipeline::Config->new->cf('PHYLOGENETICS'),
			#logger => DNALC::Pipeline::ProjectLogger->new,
			project => undef,
		}, __PACKAGE__;
	if ($project) {
		if (ref $project eq '' && $project =~ /^\d+$/) {
			my $proj = Project->retrieve($project);
			unless ($proj) {
				print STDERR "Phylogenetics Project with id=$project wasn't found!", $/;
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
sub create_project {
	my ($self, $params) = @_;
	
	my ($status, $msg) = ('fail', '');
	my $name = $params->{name};
	my $user_id = $params->{user_id};
	my $data = $params->{data};

	my $proj = $self->search(user_id => $user_id, name => $name);
	if ($proj) {
		return {status => 'fail', msg => "There is already a project named \"$name\"."};
	}
	# create project
	$proj = eval { Project->create({
				user_id => $user_id,
				name => $name,
			});
		};
	if ($@) {
		$msg = "Error creating the project: $@";
		print STDERR  $msg, $/;
		return {status => 'fail', msg => $msg};
	}
	print STDERR  "NEW PID = ", $proj, $/;
	
	$self->project($proj);
	
	$self->create_work_dir;

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
sub add_data {
	my ($self, $params) = @_;

	my $data_src = $self->project->add_to_datasources({
			name => $params->{source},
		});
	return unless $data_src;

	print STDERR "TODO: add more checks\n";
	
	unless (-e $self->work_dir) {
		$self->create_work_dir;
	}

	my $fasta = $self->fasta_file;
	open (my $fasta_fh, ">> $fasta");
	#print STDERR "fh1 = ", $fasta_fh, $/;
	lock $fasta_fh, LOCK_EX or print STDERR "Unable to lock fasta file!!!\n$!\n";
	#my $out_io  = Bio::SeqIO->new(-file => ">> $fasta", -format => 'Fasta', -flush  => 0);
	my $out_io  = Bio::SeqIO->new(-fh => $fasta_fh, -format => 'Fasta', -flush  => 0);

	#print STDERR "fh2 = ", $out_io->fh, $/;
	
	my $ab = Bio::Trace::ABIF->new if $params->{type} =~ /trace/i;

	my @files = @{$params->{files}};
	for my $f (@files) {
		#print "\tadding file: $f\n";

		# store files
		# this will return the path of the stored file, if any
		#my $stored_file = $self->store_file(src => $f, target => 'x', type => 'yy');
		my $stored_file = $f;

		my $data_file = DataFile->create({
					project_id => $self->project,
					source_id => $data_src,
					file_name => basename ($f),
					file_path => $stored_file,
					file_type => $params->{type},
				});
		#$data_file = undef;
		#print STDERR "data file: ", $data_file ? $data_file->id : "undef", $/;
		#print STDERR "data src: ", $data_src ? $data_src->id : "undef", $/;
		# store sequences
		# FASTA files
		if ($params->{type} =~ /fasta/i) {
			my $seqio = Bio::SeqIO->new(-file => $f);
			while (my $seq_obj = $seqio->next_seq) {
				#print ">", $seq_obj->display_id, $/;
				#print $seq_obj->seq, $/;
				
				my $seq = DataSequence->create({
						project_id => $self->project,
						source_id => $data_src,
						file_id => $data_file ? $data_file->id : undef,
						display_id => $seq_obj->display_id,
						seq => $seq_obj->seq,
					});
				$out_io->write_seq($seq_obj);
			}
		}
		# AB1 files
		elsif ($params->{type} =~ /trace/i) {
			my $rc = $ab->open_abif($f);
			my $sequence = $ab->sequence;
			my $display_id = basename($f);
			$display_id =~ s/\..*?$//;
			#print $rc, $/;
			my $seq_obj = Bio::Seq->new(
					-seq => $sequence,
					-id => $display_id,
				);
			my $seq = DataSequence->create({
						project_id => $self->project,
						source_id => $data_src,
						file_id => $data_file ? $data_file->id : undef,
						display_id => $display_id,
						seq => $sequence,
					});
			#print ">", $seq_obj->display_id, $/;
			$out_io->write_seq($seq_obj);
		}
	}
	$ab->close_abif if $ab;
	close $fasta_fh;
}

#-----------------------------------------------------------------------------

sub files {
	my ($self, $type) = @_;
	return unless $self->project;

	my @files = ();
	if ($type) {
		@files = DataFile->search(project_id => $self->project, file_type => $type);
	}
	else {
		@files = DataFile->search(project_id => $self->project);
	}
	wantarray ? @files : \@files;
}

#-----------------------------------------------------------------------------
sub add_pair {
	my ($self, @sequences) = @_;

	return unless @sequences == 2;

	my $pair;
	Pair->do_transaction( sub {
		$pair = Pair->create({
			project_id => $self->project,
		});
		die "Can't create pair.." unless $pair;
		for my $s (@sequences) {
			#$pair->add_to_pair_sequences($s);
			my $pq = eval {
				PairSequence->create({
					seq_id => $s->{seq_id},
					pair_id => $pair,
					project_id => $self->project,
					strand => $s->{strand},
				});
			};
			if ($@) {
				confess "Can't add sequence $s->{seq_id} to pair in project " . $self->project;
			}
		}
	});
	
	return $pair;
}

#-----------------------------------------------------------------------------
sub pairs {
	my ($self) = @_;
	return unless $self->project;
	
	my @pairs = Pair->search(project_id => $self->project);
	wantarray ? @pairs : \@pairs;
}

#-----------------------------------------------------------------------------
sub non_paired_sequences {
	my ($self) = @_;
	DataSequence->search_non_paired_sequences($self->project);
}
#-----------------------------------------------------------------------------
sub sequences {
	my ($self) = @_;
	return unless $self->project;

	my @sequences = DataSequence->search(project_id => $self->project);
	wantarray ? @sequences : \@sequences;
}
#-----------------------------------------------------------------------------
# returns the sequencesin FASTA format
#
sub alignable_sequences {
	my ($self) = @_;

	my @data = ();
	for my $pair ($self->pairs) {
		next unless $pair->concensus;
		my @pair_sequences = $pair->paired_sequences;
		my $name = join '_', map {$_->seq->display_id} @pair_sequences;
		push @data, ">pair_" . $name;
		push @data, $pair->concensus;
	}
	for my $s ($self->non_paired_sequences) {
		push @data, ('>' . $s->display_id, $s->seq);
	}
	join "\n", @data;
}
#-----------------------------------------------------------------------------
sub build_concensus {
	my ($self, $pair) = @_;
	
	return unless ref $self && $self->project;
	return unless (defined $pair && ref($pair) eq 'DNALC::Pipeline::Phylogenetics::Pair');

	my @pair_sequences = $pair->paired_sequences;
	#print STDERR Dumper( \@pair_sequences), $/;

	# check project directory exists
	my $pwd = $self->work_dir;
	return unless $pwd && -d $pwd;

	# mk tmp dir
	my $wd = File::Temp->newdir( 
				'bldcXXXXX',
				DIR => $pwd,
				CLEANUP => 1,
			);
	print STDERR "tmp dir = ", $wd->dirname, $/;

	# copy sequences to files
	# build merger params hash
	#

	my $outfile = File::Spec->catfile($wd->dirname, 'outfile.txt');
	my $outseq  = File::Spec->catfile($wd->dirname, 'outseq.txt');
	my $dbgfile = File::Spec->catfile($wd->dirname, 'debug.txt');

	my %merger_args = (
			input_files => [],
			outfile => $outfile,
			outseq => $outseq,
		);
	my $cnt = 1;
	for my $s (@pair_sequences) {
		my $seq = $s->seq;
		print STDERR  "\tseq = ",$seq->display_id, $/;
		my $seq_file = File::Spec->catfile($wd->dirname, "seq_$seq.fasta");
		my $fh = IO::File->new;
		if ($fh->open($seq_file, 'w')) {
			print $fh ">", $seq->display_id, "\n";
			print $fh $seq->seq;
			push @{$merger_args{input_files}}, $seq_file;
			$merger_args{"sreverse$cnt"} = 1 if $s->strand ne 'F';
		}
		$cnt++;
	}
	#print STDERR Dumper( \%merger_args), $/;
	my $merger = DNALC::Pipeline::Process::Merger->new($wd->dirname);
	$merger->run(%merger_args);
	#print STDERR "\nexit code = ", $merger->{exit_status}, $/;

	if ($merger->{exit_status} == 0) { # success
		my $alignment = slurp($outfile);
		$alignment =~ s/#{3,}.*Report_file.*#{3,}\n*//ms;

		my $concensus = uc slurp($outseq);
		$concensus =~ s/>.*//;
		$concensus =~ s/\n//g;

		$pair->alignment($alignment);
		$pair->concensus($concensus);
		$pair->update;
	}
	#print STDERR Dumper( $merger ), $/;

	return 1;
}

#-----------------------------------------------------------------------------
sub build_alignment {
	my ($self) = @_;

	my $seq_fasta = $self->alignable_sequences;
	return unless $seq_fasta;

	my $pwd = $self->work_dir;
	return unless $pwd && -d $pwd;

	#my $wd = File::Temp->newdir( 
	#			'algnXXXXX',
	#			DIR => $pwd,
	#			CLEANUP => 0,
	#		);
	#my $fasta_file = File::Spec->catfile($wd->dirname, 'fasta.fas');
	my $fasta_file = File::Spec->catfile($pwd, 'to_align.fas');
	my $fh = IO::File->new;
	if ($fh->open($fasta_file, 'w')) {
		flock $fh, LOCK_EX;
		print $fh $seq_fasta;
		flock $fh, LOCK_UN;
	}

	#my $m = DNALC::Pipeline::Process::Muscle->new($wd->dirname);
	my $m = DNALC::Pipeline::Process::Muscle->new($pwd);

	my $st = $m->run(pretend=>0, debug => 1, input => $fasta_file);
	#print STDERR Dumper( $m ), $/;
	print STDERR  "exit_status: ", $m->{exit_status}, $/;
	print STDERR  "elapsed: ", $m->{elapsed}, $/;

	print STDERR "Fasta out: ", $m->get_output, $/;
	print STDERR "html out: ", $m->get_output('html'), $/;
	return $m->get_output;
}
#-----------------------------------------------------------------------------
sub get_alignment {
	my ($self) = @_;

	my $pwd = $self->work_dir;
	return unless -d $pwd;
	my $mcf = DNALC::Pipeline::Config->new->cf('MUSCLE');
	my $f = File::Spec->catfile($pwd, 'MUSCLE', $mcf->{option_output_files}->{"-fastaout"});
	return $f if -f $f;
}
#-----------------------------------------------------------------------------
sub trim_alignment {
	my ($self, $params) = @_;

	my $alignment = $self->get_alignment;
	return unless $alignment;
	return unless ($params->{left} || $params->{rigth});

	my ($l_trim, $r_trim) = ($params->{left} || 0, $params->{right} || 0);

	my $aio = Bio::AlignIO->new('-file' => $alignment);

	my $trimmed_fasta = '';
	while (my $aln = $aio->next_aln) {
		for my $seq ($aln->each_seq) {

			my $s = $seq->seq;
			$s = substr $s, 0, length($s) - $r_trim if $r_trim;
			$s = substr $s, $l_trim;
			#$s = substr $seq->seq, $l_trim, length($s) - $r_trim;
			#print "x", $s =~ s/^.{$l_trim}// if $l_trim;
			#print "x", $s =~ s/.{$r_trim}$// if $r_trim;

			$trimmed_fasta .= '>' . $seq->display_id . "\n";
			$trimmed_fasta .= $s . "\n";
		}
	}
	return $trimmed_fasta;
}
#-----------------------------------------------------------------------------

sub store_file {
	my ($self, $params) = @_;
	
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
sub work_dir {
	my ($self) = @_;
	return unless ref $self eq __PACKAGE__;
	my $proj = $self->project;
	unless ($proj)  {
		confess "Project is missing...\n";
		return;
	}

	return File::Spec->catfile($self->config->{PROJECTS_DIR}, sprintf("%04X", $proj->id));
}
#-----------------------------------------------------------------------------
sub config {
	my ($self) = @_;

	$self->{config};
}
#-----------------------------------------------------------------------------
sub search {
	my ($self, %args) = @_;

	Project->search(%args);
}

#-----------------------------------------------------------------------------
sub has_fasta_file {
	my ($self) = @_;
	return $self->fasta_file && -f $self->fasta_file;
}
#-----------------------------------------------------------------------------
sub fasta_file {
	my ($self) = @_;
	my $wd = $self->work_dir;
	return File::Spec->catfile($wd, 'fasta.fa');
}
#-----------------------------------------------------------------------------

1;
