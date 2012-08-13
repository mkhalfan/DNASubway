package DNALC::Pipeline::App::Phylogenetics::ProjectManager;


use common::sense;

use Fcntl qw/:flock/;
use IO::File ();
use IO::Scalar ();
use File::Basename;
use File::Path;
use File::Spec;
use File::Copy;
use File::Slurp qw/slurp/;
use Carp;
use Digest::MD5();
use POSIX qw/strftime floor/;
use Data::Dumper;

#use DNALC::Pipeline::ProjectLogger ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw/lcs_name isin random_string/;
use aliased 'DNALC::Pipeline::Phylogenetics::Project';
use aliased 'DNALC::Pipeline::Phylogenetics::DataSource';
use aliased 'DNALC::Pipeline::Phylogenetics::DataFile';
use aliased 'DNALC::Pipeline::Phylogenetics::DataSequence';
use aliased 'DNALC::Pipeline::Phylogenetics::Pair';
use aliased 'DNALC::Pipeline::Phylogenetics::PairSequence';
use aliased 'DNALC::Pipeline::Phylogenetics::Tree';
use aliased 'DNALC::Pipeline::Phylogenetics::Alignment';
use aliased 'DNALC::Pipeline::Phylogenetics::Workflow';
use aliased 'DNALC::Pipeline::Phylogenetics::Blast';
use aliased 'DNALC::Pipeline::Phylogenetics::BlastRun';

use DNALC::Pipeline::Process::Phylip::DNADist ();
use DNALC::Pipeline::Process::Phylip::Neighbor ();
use DNALC::Pipeline::Process::Merger ();
use DNALC::Pipeline::Process::Muscle();
use DNALC::Pipeline::CacheMemcached ();
use DNALC::Pipeline::Task ();
use DNALC::Pipeline::TaskStatus ();

use Bio::SearchIO ();
use Bio::SeqIO ();
use Bio::AlignIO ();
use Bio::Trace::ABIF ();

{
	my %status_map = (
			"not-processed" => 1,
			"done"          => 2,
			"error"         => 3,
			"processing"    => 4
		);
	my %status_id_to_name = reverse %status_map;

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
		#my $data = $params->{data};

		my $proj = $self->search(user_id => $user_id, name => $name);
		if ($proj) {
			return {status => 'fail', msg => "There is already a project named \"$name\"."};
		}
		# create project
		$proj = eval { Project->create({
					user_id => $user_id,
					name => $name,
					type => $params->{type},
					has_tools => $params->{has_tools},
					sample => $params->{sample} || 0,
					description => substr($params->{description} || '', 0, 140),
				});
			};
		if ($@) {
			$msg = "Error creating the project: $@";
			print STDERR  $msg, $/;
			return {status => 'fail', msg => $msg};
		}
		#print STDERR  "NEW PID = ", $proj, $/;
		
		$self->project($proj);
		
		$self->create_work_dir;

		return {status => 'success', msg => $msg};
	}
	#-----------------------------------------------------------------------------
	# creates a copy of the project, the ProjectManager will contain the new project
	# it returns a hashref: {status => 'x', msg => 'y'}
	# 
	sub duplicate_project {
		my ($self, $params) = @_;
		
		my ($status, $msg) = ('fail', '');
		my $oproj = $self->project;
		return {status => $status, msg => "Can't duplicate undefined project."} unless $oproj;

		# find a better name
		my $name = $oproj->name . '_' . random_string(3,8);
		my $user_id = $params->{user_id};

		# create project
		my $proj = eval { $oproj->copy({
					user_id => $user_id,
					name => $name,
				});
			};
		if ($@) {
			$msg = "Error duplicating the project: $@";
			print STDERR $msg, $/;
			return {status => 'fail', msg => $msg};
		}
		#print STDERR  "NEW PID = ", $proj, $/;
		
		my $o_work_dir = $self->work_dir;

		my $mp = $proj->master_project;
		$mp->public(0);
		$mp->update;

		my %source_map = ();
		my %file_map = ();
		my %seq_map = ();
		my %status_map = ();
		my %pair_map = ();

		for (qw/phy_trim phy_pair phy_consensus/) {
			$status_map{$_} = $self->get_task_status($_)->name;
		}

		# duplicate sources
		for my $s (DataSource->search(project_id => $oproj->id)) {
			my $cs = $s->copy({project_id => $proj->id});
			$source_map{$s->id} = $cs->id;
		}

		# duplicate files
		for my $f (DataFile->search(project_id => $oproj->id)) {
			my $cf = $f->copy({project_id => $proj->id, source_id => $source_map{$f->source_id}});
			$file_map{$f->id} = $cf->id;
		}

		# duplicate sequences
		for my $s ($self->sequences) {
			my $cs = $s->copy({
						project_id => $proj->id, 
						file_id => $file_map{ $s->file_id }, 
						source_id => $source_map{ $s->source_id },
					});
			if (defined $s->left_trim) {
				print "Defined left_trim in seq: ", $s, $/;
				$cs->left_trim($s->left_trim);
				$cs->right_trim($s->right_trim);
				$cs->start_pos($s->start_pos);
				$cs->end_pos($s->end_pos);
				$cs->update;
			}
			$seq_map{$s->id} = $cs->id;
		}
		
		if ($status_map{phy_pair} eq 'done') {
			for my $pair ($self->pairs) {
				my $cpair = $pair->copy({
						project_id => $proj->id,
						alignment => $status_map{phy_consensus} eq 'done' ? $pair->alignment : '',
						consensus => $status_map{phy_consensus} eq 'done' ? $pair->consensus : '',
					});
				$pair_map {$pair->id} = $cpair->id;
				for my $pq ($pair->paired_sequences) {
 					my $npq = eval {
 						PairSequence->create({
 							seq_id => $seq_map{ $pq->seq->id },
 							pair_id => $cpair->id,
 							project_id => $proj->id,
 							strand => $pq->strand,
 						});
 					};
 					if ($@) {
 						confess "Can't  sequence ", $npq->seq_id, " to pair in project " . $proj;
 					}
					#print STDERR "new seq for pair: ", $cpair, "\n", Dumper( $npq ), $/;
				}
			}
		}

		# set pm's new project
		$self->project($proj);

		$self->create_work_dir;

		my $work_dir = $self->work_dir;

		#for (qw/phy_trim phy_pair/)
		for (qw/phy_trim phy_pair phy_consensus/) {
			if ($status_map{$_} eq 'done') {
				$self->set_task_status($_, "done");
			}
		}

		# copy pairs' consensi
		if ($status_map{phy_consensus} eq 'done') {
			my $dest_dir = sprintf("%s/pairs", $work_dir);
			mkdir $dest_dir;
			for my $pair_id (keys %pair_map) {
				my $src  = sprintf("%s/pairs/pair-%d.txt", $o_work_dir, $pair_id);
				my $dest = sprintf("%s/pair-%d.txt", $dest_dir, $pair_map{$pair_id});
				copy($src, $dest) or do {
						print STDERR  "Can't copy pair file:\n", $src, " -> ", $dest, $/;
					};
			}
		}

		#print STDERR  $self->work_dir, '; exists: ', -d $self->work_dir , $/;

		return {status => 'success', msg => $msg};
	}
	#-----------------------------------------------------------------------------
	#
	# setter/getter for the project
	#
	sub project {
		my ($self, $project) = @_;
		
		if ($project) {
			$self->{project} = $project;
		}

		$self->{project};
	}
	#-----------------------------------------------------------------------------
	#
	# adds trace files or fasta files with sequences
	#
	sub add_data {
		my ($self, $params) = @_;

		my @errors = ();
		my @warnings = ();
		my $seq_count = 0;

		my $bail_out = sub { return {seq_count => $seq_count, errors => \@errors, warnings => \@warnings}};

		my $data_src = $self->project->add_to_datasources({
				name => $params->{source},
				accession =>  $params->{accession} ? substr( $params->{accession}, 0, 128) : '',
			});
		return $bail_out->() unless $data_src;

		my @files = @{$params->{files}};

		unless (-e $self->work_dir) {
			$self->create_work_dir;
		}

		my $fasta = $self->fasta_file;
		open (my $fasta_fh, ">> $fasta") or do {
				print STDERR  "Unable to open fasta file: $fasta\n$!", $/;
			};
		flock $fasta_fh, LOCK_EX or print STDERR "Unable to lock fasta file!!!\n$!\n";
		my $out_io  = Bio::SeqIO->new(-fh => $fasta_fh, -format => 'Fasta', -flush  => 0);

		my $ab = Bio::Trace::ABIF->new if $params->{type} =~ /trace/i;

		my %seq_names = map { $_->display_id => 1} $self->sequences;

		# to remove primer from the seq
		my $rmp = qr/M13([FR])(?:_-21_)?(_R)?_(?:\w\d+)/;

		for my $fhash (@files) {
			# store files
			# this will return the path of the stored file, if any
			my $stored_file = $fhash->{path};
			unless ($self->project->sample && !$params->{existing_project}) {
				$stored_file = $self->store_file( $fhash );
			}
			my $filename = $fhash->{filename};
			$filename =~ s/[\[\]\(\)\\\/:;]+/_/g;
			$filename =~ s/$rmp/$1$2/;
			$filename =~ s/_+/_/g;

			my $f = $stored_file;
			# use relative path for the file_path
			{
				my $prefix = $self->config->{PROJECTS_DIR};
				$stored_file =~ s/^$prefix\///;
			}

			my $data_file = DataFile->create({
						project_id => $self->project,
						source_id => $data_src,
						file_name => $filename || '',
						file_path => $stored_file,
						file_type => $params->{type},
					});
			#$data_file = undef;
			#print STDERR "data file: ", $data_file ? $data_file->id : "undef", $/;
			#print STDERR "data src: ", $data_src ? $data_src->id : "undef", $/;
			# store sequences
			# FASTA files
			if ($params->{type} =~ /^(?:fasta|reference)$/i) {
				# make sure we have a text file
				unless (-T $f) {
					push @errors, sprintf("File %s is not an FASTA file!", $filename);
					next;
				}
				my $seqio = Bio::SeqIO->new(-file => $f, -format => 'fasta');
				while (my $seq_obj = $seqio->next_seq) {
					#print ">", $seq_obj->display_id, $/;
					#print $seq_obj->seq, $/;
					my $display_id = $seq_obj->display_id;
					$display_id =~ s/[\[\]\(\):;]+/_/g;
					$display_id =~ s/_+/_/g;

					if (defined $seq_names{$display_id}) {
						$data_file->delete;
						push @warnings, "Sequence '$display_id' already added to this project.";
						next;
					}
					else {
						$seq_names{$display_id} = 1;
					}

					my $seq = DataSequence->create({
							project_id => $self->project,
							source_id => $data_src,
							file_id => $data_file ? $data_file->id : undef,
							display_id => $display_id,
							seq => $seq_obj->seq,
						});
					$out_io->write_seq($seq_obj);
				}

				$seq_count++;
			}
			# AB1 files
			elsif ($params->{type} =~ /trace/i) {
				my $rc = eval {
						$ab->open_abif($f);
					};

				unless ($rc && $ab->is_abif_format) {
					$ab->close_abif;
					push @errors, sprintf("File %s is not an AB1 file", $filename);
					next;
				}

				my $sequence = $ab->sequence;
				my $display_id = $filename;

				# remove file extension (if any)
				$display_id =~ s/\..*?$//;
				#remove any spaces
				$display_id =~ s/\s+/_/g;
				$display_id =~ s/[\[\]\(\):;]+/_/g;
				$display_id =~ s/$rmp/$1$2/;
				$display_id =~ s/_+/_/g;

				if (defined $seq_names{$display_id}) {
					$data_file->delete;
					push @warnings, "File '$filename' already added to this project.";
					next;
				}

				$seq_names{$display_id} = 1;

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

				eval {
					# calculate the quality score average
					my @quality_values = $ab->quality_values;
					#print STDERR  '@quality_values=', "[@quality_values]", $/;
					if (@quality_values) {
						my $total = 0;
						map { $total += $_ } @quality_values;
						if ($total / @quality_values < $self->config->{Q_THRESHOLD}) {
							$data_file->has_low_q( 1 );
							$data_file->update;
						}
					}
				};
				if ($@) {
					print STDERR  "Errors: ", $@, $/;
				}

				$seq_count++;
			}
		}
		#print STDERR "Warnings: ", Dumper( \@warnings), $/;

		$ab->close_abif if $ab && $ab->is_abif_open;
		flock $fasta_fh, LOCK_UN;
		close $fasta_fh;

		if ($params->{type} ne 'reference') {
			if ( $seq_count && $self->get_task_status('phy_trim')->name eq 'done') {
				$self->undo_trimming;
			}
		}

		return $bail_out->();
	}

	#-----------------------------------------------------------------------------
	#
	# adds a set of sequences from our reference sets
	#
	sub add_reference {
		my ($self, $ref_id) = @_;

		return unless $self->project;
		my $type = $self->project->type;
		my $ref_cf = DNALC::Pipeline::Config->new->cf('PHYLOGENETICS_REF');
		my $refs = defined $ref_cf->{$type} ? $ref_cf->{$type} : [];
		my ($ref) = grep {$_->{id} =~ /^$ref_id$/} @$refs;
		return unless $ref;

		my $st = $self->add_data({
					source => "ref:$ref_id",
					files => [{ path => $ref->{file}, filename => basename($ref->{file})}],
					type => "reference",
				});
	}

	#-----------------------------------------------------------------------------
	#
	# returns a list of the used references in the project
	sub references {
		my ($self) = @_;

		return unless $self->project;
	
		my @sources = DataSource->search_like( 
				project_id => $self->project,
				name => 'ref:%'
			);
		my @refs = map { 
				my $r = $_->name; $r =~ s/^ref://; $r
			} @sources;

		wantarray ? @refs : \@refs;
	}
	#-----------------------------------------------------------------------------
	#
	# adds the selected or all the blast sequences 
	#
	sub add_blast_data {
		my ($self, $blast_id, $selected_sequences) = @_;

		my @errors = ();
		my @warnings = ();
		my $seq_count = 0;

		my $bail_out = sub { return {seq_count => $seq_count, errors => \@errors,  warnings => \@warnings}};

		my $blast = Blast->retrieve($blast_id);
		unless ($blast) {
			push @errors, "Blast results not found.";
			return $bail_out->();
		}

		my $data_src = $self->project->add_to_datasources({
				name => "blast:$blast_id",
			});
		return $bail_out->() unless $data_src;

		my %seq_names = map { $_->display_id => 1} $self->sequences;

		my $fasta = $self->fasta_file;
		open (my $fasta_fh, ">> $fasta") or do {
				print STDERR  "Unable to open fasta file: $fasta\n$!", $/;
			};
		#print STDERR "fh1 = ", $fasta_fh, $/;
		flock $fasta_fh, LOCK_EX or print STDERR "Unable to lock fasta file!!!\n$!\n";
		my $out_io  = Bio::SeqIO->new(-fh => $fasta_fh, -format => 'Fasta', -flush  => 0);

		my $in_fh = IO::Scalar->new;
		print $in_fh $blast->output;
		$in_fh->seek(0,0);
		my $in = Bio::SearchIO->new(-format => 'blast', -fh => $in_fh);
		
		my $out = '';

		my $num = 0;
		while( my $res = $in->next_result ) {
			while( my $hit = $res->next_hit ) {
				while( my $hsp = $hit->next_hsp ) {
					last if $num++ >= ($self->config->{MAX_BLAST_RESULTS} || 20);
					my $seq_obj = $hsp->seq("hit");
					my $name = $seq_obj->display_id;
					$name =~ s/(\.1)?\|$//;
				
					# check if $name is in the selected names
					next if (@$selected_sequences && !isin($name, @$selected_sequences));

					my @tmp = split /\s+/, $hit->description;
					my $display_id = $name . '|' . join '_', map {lc $_} splice @tmp, 0, 2;
					$display_id =~ s/\s+/_/g;
					$display_id =~ s/[\[\]\(\):;]+/_/g;
					$display_id =~ s/_+/_/g;
					$display_id =~ s/_+$//g;

					#print ">", $display_id, $/;
					if (defined $seq_names{$display_id}) {
						push @warnings, "Sequence '$display_id' already added to this project.";
						next;
					}
					$seq_names{$display_id} = 1;
					$seq_obj->display_id($display_id);
				
					my $seq = DataSequence->create({
						project_id => $self->project,
						source_id => $data_src,
						file_id => undef,
						display_id => $display_id,
						seq => $seq_obj->seq,
					});
					$out_io->write_seq($seq_obj);

					$seq_count++;
				}
			}
		}
		close $fasta_fh;
		close $in_fh;

		return $bail_out->();
	}
	#-----------------------------------------------------------------------------
	#
	# returns the traces/fasta files associated with a project
	#
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
			my $pair_name = lcs_name( map {$_->seq->display_id} $pair->paired_sequences);
			$pair->name(substr $pair_name, 0, 128);
			$pair->update;
		});
		
		return $pair;
	}

	#-----------------------------------------------------------------------------
	sub pairs {
		my ($self) = @_;
		return unless $self->project;
		
		my @pairs = Pair->search(project_id => $self->project, { order_by => 'pair_id' });
		wantarray ? @pairs : \@pairs;
	}

	#-----------------------------------------------------------------------------
	# returns the sequences that are not part of a pair
	#
	sub non_paired_sequences {
		my ($self) = @_;
		DataSequence->search_non_paired_sequences($self->project);
	}
	#-----------------------------------------------------------------------------
	#
	#
	sub sequences {
		my ($self) = @_;
		return unless $self->project;

		my @sequences = DataSequence->search(project_id => $self->project);
		wantarray ? @sequences : \@sequences;
	}
	#-----------------------------------------------------------------------------
	#
	# returns a list of sequences that were used initially at project conception
	# or added by upload or imported from DNALC
	#
	sub initial_sequences {
		my ($self) = @_;
		return unless $self->project;

		my @sequences = ();
		for my $s ( DataSequence->search_initial_non_paired_sequences($self->project) ) {
			push @sequences, $s;
		}

		wantarray ? @sequences : \@sequences;
	}

	#-----------------------------------------------------------------------------
	#
	# returns the sequences in FASTA format
	#	- first it checks the pairs that have a consensus built
	#	- then it looks for the non paired sequences
	#
	sub alignable_sequences {
		my ($self) = @_;

		my %selected_sequences = ();
		my $memcached = DNALC::Pipeline::CacheMemcached->new;
		if ($memcached) {
			my $mc_key = "selected-seq-" . $self->project->id;
			my $sel = $memcached->get($mc_key);
			if ($sel && @$sel) {
				%selected_sequences = map {$_ => 1} @$sel;
			}
		}

		my $has_selected_sequences = keys %selected_sequences;

		my @data = ();
		for my $pair ($self->pairs) {
			next if ($has_selected_sequences && !defined $selected_sequences{"p$pair"});
			next unless $pair->consensus;
			#my $name = lcs_name( map {$_->seq->display_id} $pair->paired_sequences);
			my $name = $pair->name;
			push @data, ">" . $name;
			push @data, $pair->consensus;
		}
		for my $s ($self->non_paired_sequences) {
			next if ($has_selected_sequences && !defined $selected_sequences{$s->id});
			push @data, ('>' . $s->display_id, $s->seq);
		}
		join "\n", @data;
	}
	#-----------------------------------------------------------------------------
	#
	# - builds the consensus of a pair of two seqeunces/trace files
	#
	sub build_consensus {
		my ($self, $pair) = @_;
		
		return unless ref $self && $self->project;
		return unless (defined $pair && ref($pair) eq 'DNALC::Pipeline::Phylogenetics::Pair');

		my @pair_sequences = $pair->paired_sequences;

		# no need for a consensus if one of the sequences is empty
		#return if grep {/^$/} map { $_->seq eq '' } @pair_sequences;

		# check project directory exists
		my $pwd = $self->work_dir;
		return unless $pwd && -d $pwd;

		# mk tmp dir
		my $wd = File::Temp->newdir( 
					'bldcXXXXX',
					DIR => $pwd,
					CLEANUP => 1,
				);

		# copy sequences to files
		# build merger params hash
		#

		my $outfile = File::Spec->catfile($wd->dirname, 'outfile.txt');
		my $outseq  = File::Spec->catfile($wd->dirname, 'outseq.txt');

		my %merger_args = (
				input_files => [],
				_names => {},
				outfile => $outfile,
				outseq => $outseq,
				debug => 0,
			);
		my $cnt = 1;
		for my $s (@pair_sequences) {
			my $seq = $s->seq;
			my $seq_file = File::Spec->catfile($wd->dirname, "seq_$seq.fasta");
			my $fh = IO::File->new;
			if ($fh->open($seq_file, 'w')) {
				print $fh ">", $seq->display_id, "\n";
				print $fh $seq->seq;
				push @{$merger_args{input_files}}, $seq_file;
				$merger_args{"sreverse$cnt"} = 1 if $s->strand ne 'F';
				$merger_args{"sid$cnt"} = "seq_$seq";
				$merger_args{_names}->{"seq_$seq"} = $seq->display_id;
			}
			$cnt++;
		}
		my $merger = DNALC::Pipeline::Process::Merger->new($wd->dirname);
		$merger->run(%merger_args);

		if ($merger->{exit_status} == 0) { # success

			my $pdir = File::Spec->catfile($pwd, "pairs");
			mkdir $pdir;
			my $formatted_alignment = File::Spec->catfile($pdir, "pair-$pair.txt");
			$merger->build_consensus($outfile, $outseq, $formatted_alignment);

			my $alignment = slurp($formatted_alignment);

			# create a fasta file out of the $alignment;
			my @alignment_line_1 =(split(': ',(grep {!/^Consensus\s*:/} split('\n', $alignment))[0]));
			my @alignment_line_2 =(split(': ',(grep {!/^Consensus\s*:/} split('\n', $alignment))[1]));
			my @alignment_line_3 =(split(': ',(grep {/^Consensus\s*:/} split('\n', $alignment))[0]));
			my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]); #Sequence 1
			my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]); #Sequence 2
			my ($display_name_3, $seq3) = ($alignment_line_3[0], $alignment_line_3[1]); #Consensus

			my $muscle_input = File::Spec->catfile($wd, "muscle-$pair.fasta");
			open (MYFILE, ">$muscle_input");
			print MYFILE ">$display_name_1\n$seq1\n>$display_name_2\n$seq2\n>$display_name_3\n$seq3";
			close (MYFILE);

			# call MUSCLE 
			my $m = DNALC::Pipeline::Process::Muscle->new($wd);
			my $st = $m->run(pretend=>0, debug => 0, input => $muscle_input);
			
			# parse muscle output
			my $muscle_output = slurp($wd . '/MUSCLE/output.fasta');
			my @muscle_output_array = split('>', $muscle_output);
			shift(@muscle_output_array);


			# make sure the consensus comes out on the last line
			my $muscle_alignment = '';
			my $consensus;
			my @consensus = ();
			# my @display_name_array = ($display_name_1, $display_name_2, $display_name_3);
			for my $i (0 .. 2) {
				my @temp = split('\n', $muscle_output_array[$i]);
				if ($temp[0] =~ /^Consensus/) {
					$consensus[0] = shift(@temp);
					$consensus[1] = $consensus = join('', @temp);
				}
				else {
					$muscle_alignment .= $temp[0] . ': ';
					shift (@temp);
				    my $seqa = join('', @temp);
				    $muscle_alignment .= $seqa . "\n";
				}
			}
			$muscle_alignment .= join ': ', @consensus;

			my @seq = map {$_->seq_id} @pair_sequences;
			if (DataFile->retrieve($seq[0]->file_id)->file_type eq 'trace' &&
					DataFile->retrieve($seq[1]->file_id)->file_type eq 'trace')
			{
				my $fixed_consensus = _fix_consensus($muscle_alignment, $consensus, @pair_sequences);
				if ($fixed_consensus) {
					$consensus = $fixed_consensus;
				}
			}

			$pair->alignment($muscle_alignment);
			$pair->consensus($consensus);
			$pair->update;
		}

		return 1;
	}
	
	#----------------------------------------------------------------------------
	sub _fix_consensus{
		my ( $muscle_alignment, $consensus, @pair_sequences) = @_;

		my @alignment_line_1 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[0]));
		my @alignment_line_2 = (split(/\s*:\s*/,(split('\n', $muscle_alignment))[1]));
		my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]); # Sequence 1
		my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]); # Sequence 2

		# @seq has the 2 DataSequence objects belonging to a pair
		my @seq = map {$_->seq_id} @pair_sequences;

		my ($ds_id_1, $df_id_1, $lt1, $rt1) = map {$_ && ($_->id, $_->file_id, length($_->left_trim), length($_->right_trim))} 
				grep { $_->display_id eq $display_name_1 } @seq;
		my ($ds_id_2, $df_id_2, $lt2, $rt2) = map {$_ && ($_->id, $_->file_id, length($_->left_trim), length($_->right_trim))} 
				grep { $_->display_id eq $display_name_2 } @seq;

		my ($df_1_strand) = map {$_ && $_->strand} grep { $_->seq_id eq $ds_id_1} @pair_sequences;
		my ($df_2_strand) = map {$_ && $_->strand} grep { $_->seq_id eq $ds_id_2} @pair_sequences;

		my $seq1_trimmed = $lt1;
		my $seq2_trimmed = $lt2;

		my $df1 = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($df_id_1);
		my @qs1 = $df1->quality_values if $df1;
		return unless (@qs1);
		if ($df_1_strand eq "R") {
				@qs1 = reverse @qs1;
				$seq1_trimmed = $rt1;
		}

		my $df2 = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($df_id_2);
		my @qs2 = $df2->quality_values if $df2;
		return unless (@qs2);
		if ($df_2_strand eq "R") {
				@qs2 = reverse @qs2;
				$seq2_trimmed = $rt2;
		}

		my $x = $seq1_trimmed;
		foreach (split//, $seq1) {
			if ($_ eq "-") {
				splice @qs1, $x, 0, "-1";
			}
			$x++;
		}

		my $y = $seq2_trimmed;
		foreach (split//, $seq2) {
			if ($_ eq "-") {
				splice @qs2, $y, 0, "-1";
			}
			$y++;
		}

		for (my $i = 0; $i <= length($seq1); $i++) {
			my ($chr1, $chr2) = (substr($seq1, $i, 1), substr($seq2, $i, 1));

			if ($chr1 ne "N" && $chr2 ne "N") {
				if ($chr1 ne $chr2) {
					if ($qs1[$i + $seq1_trimmed] > $qs2[$i + $seq2_trimmed]) {
						substr ($consensus, $i, 1) = $chr1;
					}
					else {
						substr ($consensus, $i, 1) = $chr2;
					}
				}
			}
		}

		return $consensus;
	}
		
	#
	# Updates the consensus sequence with the trimmed consensus from the
	# consensus editor. Will update both the 'consensus' and 'alignment' columns
	# in the phy_pair table
	#
	# @param left		the number of base pairs to trim from the left side
	# @param right		the number of base pairs to trim from the right side
	# @param pair_id	the pair id
	#----------------------------------------------------------------------------
	sub trim_consensus{
		my ($self, $args) = @_;
		
		my $pair = Pair->retrieve($args->{pair_id});
		
		unless ($pair){
			return {status=> "error", msg => 'no such pair found'};
		}

		my $alignment = $pair->alignment;
		my $consensus = $pair->consensus;

		# here we check to ensure the length of the trim values are not greater
		# than half the length of the entire sequence
		my $max_l = floor((length $consensus) / 2);
		if ($args->{left} > $max_l || $args->{right} > $max_l ){
			return {status=> "error", msg => "Invalid trim values specified. Trim values cannot be greater than $max_l."};
		}

		# the new, trimmed consensus is a substring of the original consensus starting
		# from the value of left, running the length of the consensus minus the left trim
		# amount and minus the right trim amount
		my $new_length = (length $consensus) - $args->{left} - $args->{right};
		my $new_consensus = substr $consensus, $args->{left}, $new_length;

		# parse the individual sequences from the alignment so you can manipulate them
 		my @alignment_line_1 = (split(/\s*:\s*/,(split('\n', $alignment))[0]));
        my @alignment_line_2 = (split(/\s*:\s*/,(split('\n', $alignment))[1]));
		my @alignment_line_3 = (split(/\s*:\s*/,(split('\n', $alignment))[2]));
        my ($display_name_1, $seq1) = ($alignment_line_1[0], $alignment_line_1[1]); # Sequence 1
        my ($display_name_2, $seq2) = ($alignment_line_2[0], $alignment_line_2[1]); # Sequence 2
		my ($display_name_3, $seq3) = ($alignment_line_3[0], $alignment_line_3[1]); # Sequence 3 (consensus)

		# This code below is to determine the strands for each of the 2 sequences in the 
		# alignment field (which seq is the forward and which is the reverse)
		my @pair_sequences = $pair->paired_sequences;
	 	# @seq has the 2 DataSequence objects belonging to a pair
        my @seq = map {$_->seq_id} @pair_sequences;

        my ($ds_id_1, $df_id_1, $lt1, $rt1) = map {$_ && ($_->id, $_->file_id, length($_->left_trim), length($_->right_trim))}
                grep { $_->display_id eq $display_name_1 } @seq;
        my ($ds_id_2, $df_id_2, $lt2, $rt2) = map {$_ && ($_->id, $_->file_id, length($_->left_trim), length($_->right_trim))}
                grep { $_->display_id eq $display_name_2 } @seq;

        my ($df_1_strand) = map {$_ && $_->strand} grep { $_->seq_id eq $ds_id_1} @pair_sequences;
        my ($df_2_strand) = map {$_ && $_->strand} grep { $_->seq_id eq $ds_id_2} @pair_sequences;
		
		# using the unmodified alignment, determine the number of actual nucleoties 
		# (not including dashes) which are trimmed from the sequences. These values 
		# are needed for when you need to call up the mini traces in the consensus
		# editor (so you can get the right position in the trace file). And this is
		# why we needed/computed the strands in the above step.
		my $real_f_trim = int($pair->f_trim);
		my $real_r_trim = int($pair->r_trim);
		print STDERR "\n\n df_1_strand: $df_1_strand\n\n";
		if ($df_1_strand eq "F"){
			my $seq_f = substr $seq1, 0, $args->{left};
        	my $dash_count_f = ($seq_f =~ s/-//g);
        	$real_f_trim += ($args->{left} - $dash_count_f);

			my $seq_r = substr $seq2, 0, $args->{left};
        	my $dash_count_r = ($seq_r =~ s/-//g);
			$real_r_trim += ($args->{left} - $dash_count_r);

        	print STDERR "\n\nreal left trim: $real_f_trim | real right trim: $real_r_trim\n\n";
		}
		else {
			my $seq_f = substr $seq2, 0, $args->{left};
            my $dash_count_f = ($seq_f =~ s/-//g);
            $real_f_trim += ($args->{left} - $dash_count_f);

            my $seq_r = substr $seq1, 0, $args->{left};
            my $dash_count_r = ($seq_r =~ s/-//g);
			$real_r_trim += ($args->{left} - $dash_count_r);

            print STDERR "\n\nreal left trim: $real_f_trim | real right trim: $real_r_trim\n\n";
		}	
		
		# modify the sequences in the alignment
		$seq1 = substr $seq1, $args->{left}, $new_length;
		$seq2 = substr $seq2, $args->{left}, $new_length;
		$seq3 = substr $seq3, $args->{left}, $new_length;
		
		# create the new alignment
		my $new_alignment = "$display_name_1 : $seq1\n$display_name_2 : $seq2\n$display_name_3 : $seq3";
		
		# update the DB with the new consensus and alignment
		$pair->consensus($new_consensus);
		$pair->alignment($new_alignment);
		$pair->f_trim($real_f_trim);
		$pair->r_trim($real_r_trim);

		# delete the entry for this sequence in the BlastRun table, if it exists
		# BlastRun run_id = pid . -p . pair_id (ex: 427-p1909)
		my $blast_run_id = $self->project . '-p' . $args->{pair_id};
		my ($blast_run) = BlastRun->search(run_id=>$blast_run_id);
		if ($blast_run) {
			$blast_run->delete;
		}

		if ($pair->update){
			return {status=> "success"};
		}
		else{
			return {status=> "error", message=> "failed to update db"};
		}	

	}

	#
	# builds an alignment from the projects' sequences
	# these can be selected and sored in Memcached or all alignable sequences
	# if $realign is true, we get the last alignment and we re-align it (sometimes
	# a trimmed alignment can be realigned)
	#
	# @param realign	if true, we get the last alignment and we re-align it
	# @param trim		if true, this alignment will be trimmed
	#-----------------------------------------------------------------------------
	sub build_alignment {
		my ($self, $realign, $trim) = @_;

		my $pwd = $self->work_dir;
		return unless $pwd && -d $pwd;

		my $seq_fasta = '';
		if ($realign) {
			my $alignment_file = $self->get_alignment;
			my $fh = IO::File->new;
			if ($fh->open($alignment_file)) {
				flock $fh, LOCK_SH;
				while(<$fh>) {
					$seq_fasta .= $_;
				}
				flock $fh, LOCK_UN;
			}
		}
		else {
			
			$seq_fasta = $self->alignable_sequences;
		}
		return unless $seq_fasta;

		my $fasta_file = File::Spec->catfile($pwd, 'to_align.fas');
		my $fh = IO::File->new;
		if ($fh->open($fasta_file, 'w')) {
			flock $fh, LOCK_EX;
			print $fh $seq_fasta;
			flock $fh, LOCK_UN;
		}

		my $m = DNALC::Pipeline::Process::Muscle->new($pwd);

		my $st = $m->run(pretend=>0, debug => 0, input => $fasta_file);

		my ($output, $phy_out);

		if (defined $m->{exit_status} && $m->{exit_status} == 0) { # success
			$output = $m->get_output;
		}
		
		if ($output && -f $output) {

			$phy_out = $m->convert_fasta_to_phylip;
			$self->_store_alignments($phy_out);

			# get the project type
			my $project_type = $self->project->type;

			# send the --is_amino switch if it's a protein trype project
			my $is_amino = ($project_type eq "protein" ? "--is_amino" : '');
			
			my $do_trim = ($trim ? '--do_trim' : '' );

			my $st = $m->do_postprocessing($self->project, $output, $is_amino, $do_trim);

			my $html_output = $st->{html_output} if $st;
			my $trimmed_alignment = $st->{trimmed_output} if $st;
			if (defined $html_output && -f $html_output) {
				$self->_store_alignments($html_output);
			}
			
			if ($trim && defined $trimmed_alignment && -f $trimmed_alignment) {
				$self->_store_alignments($trimmed_alignment);
			}
			else {
				$self->_store_alignments($output);
			}

			$self->set_task_status("phy_alignment", "done", $m->{elapsed});
		}
		else {
			$self->set_task_status("phy_alignment", "error");
		}

		return $output;
	}
	#-----------------------------------------------------------------------------
	# returns the path to the alignment file (default format is fasta)
	#	or undef if the file doesn't exist
	#
	sub get_alignment {
		my ($self, $format) = @_;

		$format ||= 'fasta';

		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $out_file;

		my $mcf = DNALC::Pipeline::Config->new->cf('MUSCLE');
		my ($out_type) = grep (/$format/i, keys %{$mcf->{option_output_files}});
		if ($out_type) {

			my $alignments_store = File::Spec->catfile($self->work_dir, 'alignments');
			if (-d $alignments_store) {
				($out_file)=sort {$b cmp $a } <$alignments_store/*.$format>;
			}
			$out_file ||= File::Spec->catfile($pwd, 'MUSCLE', $mcf->{option_output_files}->{$out_type});
		}

		return $out_file if ($out_file && -f $out_file);
	}

	#-----------------------------------------------------------------------------
	# trims the last alignment
	#
	sub trim_alignment {
		my ($self, $params) = @_;

		my $alignment_file = $self->get_alignment;
		return unless $alignment_file;
		return unless ($params->{left} || $params->{right});

		my ($l_trim, $r_trim) = ($params->{left} || 0, $params->{right} || 0);

		my $aio; #Bio::AlignIO object
		open (my $afh, $alignment_file) || 
			confess "Can't read alignment: ", $/;

		flock $afh, LOCK_SH or print STDERR "Unable to lock fasta file!!!\n$!\n";
		$aio = Bio::AlignIO->new(-fh => $afh, -format => 'fasta');

		my $trimmed_fasta = '';
		while (my $aln = $aio->next_aln) {
			for my $seq ($aln->each_seq) {
				my $s = $seq->seq;
				$s = substr $s, 0, length($s) - $r_trim if $r_trim;
				$s = substr $s, $l_trim;

				$trimmed_fasta .= '>' . $seq->display_id . "\n";
				$trimmed_fasta .= $s . "\n";
			}
		}

		flock $afh, LOCK_UN;
		$afh->close;

		# now write the trimmed alignment
		$afh = IO::File->new;
		if ($afh->open($alignment_file, 'w')) {
			flock $afh, LOCK_EX;
			print $afh $trimmed_fasta;
			flock $afh, LOCK_UN;
			$afh->close;
		}
		else {
			print STDERR  "Unable to write trimmed alignment..", $/;
		}
		print STDERR  "size 2: ", -s $alignment_file, $/;
		return $trimmed_fasta;
	}

	#-----------------------------------------------------------------------------
	#
	sub undo_trimming {
		my ($self) = @_;
		#my @seqs = $self->initial_sequences;
		#DataSequence->undo_trimming($self->project->id);
		$self->set_task_status('phy_trim', 'not-processed');
	}

	#-----------------------------------------------------------------------------
	#
	sub compute_dist_matrix {
		my ($self) = @_;

		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $dnadist_input = $self->get_alignment('phyi');
		return unless $dnadist_input;

		my $d = DNALC::Pipeline::Process::Phylip::DNADist->new($pwd);

		my $rc = $d->run(input => $dnadist_input, debug => 0);

		if ($rc == 0) {
			my $dist_file = $d->get_output;
			return $dist_file;
		}
		return;
	}
	#-----------------------------------------------------------------------------
	# params: 
	#	$dist_tree => the path to the tree created by neighbor
	# returns {tree => $tree_object, tree_file => $stored_tree_file}
	#
	sub compute_tree {
		my ($self, $dist_file) = @_;

		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $p = DNALC::Pipeline::Process::Phylip::Neighbor->new($pwd);

		my $rc = $p->run( input => $dist_file, debug => 1 );
		if ($rc == 0) {
			#print STDERR  "exit_status: ", $p->{exit_status}, $/;
			print STDERR  "elapsed: ", $p->{elapsed}, $/;

			my $stored_tree = $self->_store_tree($p->get_tree);
			return $stored_tree if ($stored_tree && $stored_tree->{tree});
		}

		return;
	}

	#-----------------------------------------------------------------------------
	# returns the latest tree of the specified format found in the database
	#
	sub get_tree {
		my ($self, $tree_type) = @_;

		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $project = $self->project;
		return unless $project;

		my ($tree, $tree_file);

		my $tree_dir = File::Spec->catfile($pwd, 'trees');
		#print STDERR "Trees are in ", $tree_dir, $/;
		unless (-e $tree_dir) {
			unless (mkdir $tree_dir) {
				print STDERR  "Unable to create tree dir for project: ", $project, $/;
				return;
			}
		}
		my $trees = Tree->search(project_id => $project->id,  tree_type => $tree_type, {order_by => 'id DESC' });
		#print STDERR "Trees= ", $trees, $/;
		if ($trees) {
			$tree = $trees->next;
			$tree_file = File::Spec->catfile($tree_dir, sprintf("%d-%s.nw", $tree->id, $tree_type) );

			#play nice with older tree files
			unless (-f $tree_file) {
				$tree_file = File::Spec->catfile($tree_dir, sprintf("%d.nw", $tree->id) );
			}
		}

		return {tree => $tree, tree_file => $tree_file};
	}

	#-----------------------------------------------------------------------------
	# stores the tree o the disk and their paths into the database
	#
	sub _store_tree {
		my ($self, $file, $tree_type, $alignment) = @_;

		return unless ($file && -f $file);

		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $project = $self->project;
		return unless $project;

		my $tree = eval {
			Tree->create({
				project_id => $project,
				tree_type => $tree_type,
				alignment => $alignment ? basename($alignment) : '',
			});
		};
		if ($@) {
			print STDERR "Error storing tree: $@", $/;	
			return;
		}

		my $tree_dir = File::Spec->catfile($pwd, 'trees');
		unless (-e $tree_dir) {
			unless (mkdir $tree_dir) {
				print STDERR  "Unable to create tree dir for project: ", $project, $/;
				return;
			}
		}
		my $tree_file = File::Spec->catfile($tree_dir, sprintf("%d-%s.nw", $tree->id, $tree_type) );
		unless (move $file, $tree_file) {
			return;
		}

		return {tree => $tree, tree_file => $tree_file};
	}

	#-----------------------------------------------------------------------------
	# stores the Muscle files on disk and into the DB 
	#
	sub _store_alignments {
		my ($self, @files) = @_;

		return unless (@files);

		my $project = $self->project;
		return unless $project;
	
		my $pwd = $self->work_dir;
		return unless -d $pwd;

		my $store = File::Spec->catfile($self->work_dir, 'alignments');
		unless (-d $store ) {
			unless(mkdir $store) {
				print STDERR  "Unable to create dir for storing alignments for project: ", $self->project, $/;
				return;
			}
		}

		my $time = POSIX::strftime "%y%m%d.%H%M%S", localtime(+time);
		my @stored_files;
		for my $f (@files) {
			unless (-f $f) {
				push @stored_files, undef;
				next;
			}
			my $new_f = $f;
			$new_f =~ s/(.*\/).*(\.\w+)$/$time$2/;
			$new_f = File::Spec->catfile($store, $new_f);
			copy $f, $new_f;
			push @stored_files, $new_f;

			my ($ext) = $new_f =~ /\.(\w{2,5})$/;
			# store in DB also
			my $aln = eval {
				Alignment->create({
					project_id => $project,
					aln_type => $ext,
					file => $new_f ? basename($new_f) : '',
				});
			};
			if ($@) {
				print STDERR "Error storing alignment: $@", $/;	
				return;
			}
			#print STDERR Dumper( $aln ), $/;

		}

		return @stored_files;
	}

	#-----------------------------------------------------------------------------
	# stores the sequence/trace files added to the project
	#
	sub store_file {
		my ($self, $fhash) = @_;

		my $source_file = $fhash->{path};

		my $store = File::Spec->catfile($self->work_dir, 'data_files');
		unless (-d $store ) {
			unless(mkdir $store) {
				print STDERR  "Unable to create dir for storing files for project: ", $self->project, $/;
				return $source_file;
			}
		}

		my $target_file = File::Spec->catfile($store, $fhash->{filename} || basename($source_file));
		$target_file =~ s/[\s]+/_/g;
		if (move $source_file, $target_file) {
			#print STDERR  "++ moved to :", $target_file, $/;
			return $target_file;
		}
		else {
			#print STDERR  "-- not moved :", $source_file, $/;
			return $source_file;
		}
	}

	#-----------------------------------------------------------------------------
	# performs a blast search, but first checks if the results are already in the DB
	#
	sub do_blast_sequence {
		my ($self, %args) = @_;

		my $bail_out = sub { return {status => 'error', 'message' => shift } };

		my $seq_str;
		my $blast;
		my $status = 'success';

		my $seq = $args{seq};
		my $pair = $args{pair};
		my $type = $args{type};

		unless ($type && $type =~ /sequence|consensus/) {
			return $bail_out->("Blast: Missing or invalid type specified.");
		}

		if ($type =~ /^sequence/) {
			unless ( ref ($seq) =~ /DataSequence/) {
				($seq) = DataSequence->search(
						project_id => $self->project->id,
						id => $seq,
					);
			}
			$seq_str = $seq->seq if $seq;
		}
		else {
			unless ( ref ($pair) =~ /Pair$/) {
				($pair) = Pair->search(
						project_id => $self->project->id,
						pair_id => $pair,
					);
			}
			$seq_str = $pair->consensus if $pair;
		}

		#print STDERR  'seq = ', $seq_str, $/;

		my $ctx = Digest::MD5->new;
		$ctx->add($seq_str);
		my $crc = $ctx->hexdigest;

		# see if we already have cached such sequence
		($blast) = Blast->search( crc => $crc );
		if ($blast) {
			#make a new entry for this run
			my $blast_new = DNALC::Pipeline::Phylogenetics::BlastRun->create({
				run_id => $args{run_id},
				bid => $blast,
			});
			return {status => 'success', blast => $blast};
		}
		
		my $pwd = $self->work_dir;
		my $tdir = File::Temp->newdir(
                    'blast_XXXXX',
                    DIR => $pwd,
                    CLEANUP => 1,
                );
		my $in_file = File::Spec->catfile($tdir->dirname, 'input.txt');
		my $out_file = File::Spec->catfile($tdir->dirname, 'output.txt');

		my $fh = IO::File->new;
		if ($fh->open($in_file, 'w')) {
			print $fh $seq_str;
			$fh->close;
		}
		else {
			print STDERR "Can't write file $in_file", $/;
			return $bail_out->('Error: Cannot process sequence.');
		}
		
		my @args = (
				'-p', $type =~ /protein/ ? 'blastp' : 'blastn',
				'-d', 'nr',
				'-i', $in_file,
				'-o', $out_file,
			);
		#print STDERR 'blast args: ', Dumper( \@args ), $/;

		my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
		my $blast_script = File::Spec->catfile($pcf->{EXE_PATH}, 'web_blast.pl');
		my $rc = system($blast_script, @args);
		print STDERR "blast rc = $rc\n";

		# 0 == success
		# 2 == success, no results
		if ((0 == $rc || 2 == $rc) && -f $out_file) {
			my $alignment = '';
			if ($fh->open($out_file)) {
				while (<$fh>) {
					$alignment .= $_;
				}
				$fh->close;			
			}
			$blast = DNALC::Pipeline::Phylogenetics::Blast->create({
					project_id => $self->project->id,
					sequence_id => $seq,
					crc => $crc,
					output => $alignment || 'No results!',
				});
			my $blast_new = DNALC::Pipeline::Phylogenetics::BlastRun->create({
				run_id => $args{run_id},
				bid => $blast,
			});
			
			$status = 'success';

		}

		return {status => $status, blast => $blast};

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
	# utility to update the status of a blue line task
	#
	sub set_task_status {
		my ($self, $task_name, $status_name, $duration) = @_;

		unless (defined $status_map{ $status_name }) {
			print STDERR  "Unknown status: ", $status_name, $/;
			croak "Unknown status: ", $status_name, $/;
		}

		my ($task) = DNALC::Pipeline::Task->search(name => $task_name );
		unless ($task) {
			print STDERR  "Unknown task: ", $task_name, $/;
			croak "Unknown task: ", $task_name, $/;
		}

		my $wf = Workflow->retrieve(
					project_id => $self->project->id,
					task_id => $task,
				);
		if ($wf) {
			$wf->status_id($status_map{ $status_name });
			$wf->duration( $duration ? $duration : 0);
			$wf->update;
		}
		else {
			$wf = eval{
				Workflow->create({
					project_id => $self->project->id,
					task_id => $task,
					status_id => $status_map{ $status_name },
					duration => $duration ? $duration : 0,
				});
			};
			if ( $@ ) {
				print STDERR  "Can't add workflow details: ", $@, $/;
			}
		}
		$wf->status;
	}
	#-----------------------------------------------------------------------------
	sub get_task_status {
		my ($self, $task_name) = @_;

		my ($task) = DNALC::Pipeline::Task->search(name => $task_name );
		unless ($task) {
			print STDERR  "Unknown task: ", $task_name, $/;
			croak "Unknown task: ", $task_name, $/;
		}

		my ($wf) = Workflow->search(
					project_id => $self->project->id,
					task_id => $task,
				);

		unless ($wf) {
			return DNALC::Pipeline::TaskStatus->retrieve( $status_map{'not-processed'} );
		}
		$wf->status;

	}
}

1;
