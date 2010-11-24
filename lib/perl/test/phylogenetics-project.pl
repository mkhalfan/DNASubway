#!/usr/bin/perl 

use common::sense;

use FindBin;
use lib "$FindBin::Bin/..";
use DNALC::Pipeline::Phylogenetics::Project ();
use DNALC::Pipeline::App::Phylogenetics::ProjectManager ();
use Getopt::Long;
use File::Basename;

use Data::Dumper;


my ($PID, $ACTION);
GetOptions(
  'pid=i'		=> \$PID,
  'action=s'	=> \$ACTION,
);

my ($proj, $pm, $data_src);

my %actions = (
		add => 1,
		add_ref => 1,
		display => 1,
		merge_pairs => 1,
		align => 1,
		tree => 1,
		blast => 1,
	);

my $action = $ACTION && defined $actions{$ACTION} ? $ACTION : 'display';

die "\nProject id wasn't specified!!\n\n"
	if ( $action ne "add" && !defined $PID);

# project to display ( used when $action ne 'add )
my $proj_id = $PID;

#------------------------------------
# 1. project
if ($action eq 'add') {
	my $projects = DNALC::Pipeline::Phylogenetics::Project->retrieve_all;
	my $proj_name = sprintf('some project - %s', $projects->count + 1);

	$pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new;
	my $st = $pm->create_project({
			name => $proj_name,
			user_id => 90,
			has_tools => 1,
			type => 'rbcl',
			description => 'my desc',
		});
	print STDERR "new p = ", Dumper($st), $/;
	$proj = $pm->project;
}
else {
	$proj = DNALC::Pipeline::Phylogenetics::Project->retrieve($proj_id);
	die "Can't find project with pid = $proj_id\n"
		unless $proj;
	$pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($proj);
}

print STDERR "project = ", $proj, $/;
print STDERR "project dir = ", $pm->work_dir, $/;

#------------------------------------
# 2. data source
# this is handled together with the files

#------------------------------------
# 3. data files
if ($action eq 'add') {
	if (1) {
		my @files = map {{
				path => $_,
				filename => basename($_),
			}} </home/cornel/tmp/paiwisealignment/fasta/*>;
		#print STDERR "files to add = ", scalar (@files), $/;
		my $st = $pm->add_data({
			source => "init",
			files => \@files,
			type => "fasta",
		});
		print STDERR Dumper( $st ), $/;
	}
	if (1) {
		my @files = map {{
				path => $_,
				filename => basename($_),
			}} </home/cornel/tmp/paiwisealignment/sequences/*.ab1>;
		#print STDERR "files to add = ", scalar (@files), $/;
		#print STDERR "files = ", Dumper(\@files), $/;
		#exit;
		my $st = $pm->add_data({
				source => "init",
				files => \@files,
				type => "trace",
		});
		print STDERR Dumper( $st ), $/;
	}
}


#------------------------------------
# 4. pair sequences
if ($action eq 'add') {
	my @sequences = $pm->sequences;
	for (my $i = 0; $i < 10; $i += 2) {
		my $strand = rand(2) < 1 ? 'F' : 'R';
		my $pair = $pm->add_pair(
				{seq_id => $sequences[$i],
				 strand => $strand,
				},
				{seq_id => $sequences[$i+1],
				 strand => $strand eq 'F' ? 'R' : 'F',
				}
			);
		print "added pair ", $pair, $/;
	}
}


#__END__
#------------------------------------

if ($action eq 'merge_pairs') {
	print "\nSeq pairs:\n";
	for my $p ($pm->pairs) {
		print "PS= ", $p, ": ", join(',', $p->paired_sequences), $/;
		my $rc = $pm->build_consensus($p);
		#print "build_concensus = ", $rc, $/;
		#print STDERR  $p->concensus, $/;
		#print STDERR  "---------------", $/;

	}
	$pm->set_task_status('phy_concensus', 'done');
}

if ($action =~ /^add_ref/) {
	print STDERR  "Adding ref...", $/;
	my $ref_cf = DNALC::Pipeline::Config->new->cf('PHYLOGENETICS_REF');
	my $type = $pm->project->type;
	my $refs = defined $ref_cf->{$type} ? $ref_cf->{$type} : [];
	print STDERR Dumper( $refs->[0] ), $/;
	$pm->add_reference($refs->[0]->{id}) 
		if @$refs;
}

#------------------------------------

if ($action =~ /^(?:add|display)$/) {

	print STDERR  "project type = ", $proj->type, $/;
	if ($pm->has_fasta_file) {
		print STDERR "fasta = ", $pm->fasta_file, $/;
	}
	else {
		print STDERR "No fasta file for this project\n";
	}

	for (qw/phy_concensus phy_alignment phy_tree/) {
		print STDERR  "$_:\t", $pm->get_task_status($_)->name, $/;
	}
	print "------------------------------------\n";

	for (qw/fasta trace/) {
		my @files = $pm->files($_);
		if (@files) {
			print "$_ files: ", scalar(@files), $/;
			#print "files[0] seq = \n", $files[0]->seq, $/;
			if ($_ =~ /^trace$/i) {
				my @q = $files[0]->quality_values;
				#print STDERR Dumper( $files[0]), $/;
				print "qualities: ", scalar @q, $/;
			}
		}
	}
	print "------------------------------------\n";
	print "All sequences:\n";
	my @sequences = $pm->sequences;
	print "@sequences", $/;
	print $sequences[0]->display_id, $/;
	#print $sequences[0]->seq, $/;


	print "------------------------------------\n";

	print "Seq pairs:\n";
	for my $pair ($pm->pairs) {
		print "PS= ", $pair, ": ", join(',', $pair->paired_sequences), $/;
		#print $pair->concensus, $/;
	}
	#------------------------------------
	print "\nNon paired sequences:\n";
	print join(' ', $pm->non_paired_sequences), $/;
	print "------------------------------------\n";
	my $alignment = $pm->get_alignment;
	print "alignment = ", $alignment, $/ if $alignment;
} #end if add|display

if ($action eq 'align') {

	$pm->build_alignment;
	
	print "alignment = ", $pm->get_alignment, $/;

	# trim
	$pm->trim_alignment({left => 30, right => 20});

	# realign
	$pm->build_alignment(1);
}

if ($action eq 'tree') {
	print "------------------------------------\n";
	my $phyi_file = $pm->get_alignment('phyi');

	print "Alignment file: $phyi_file\n";

	my $dist_file = $pm->compute_dist_matrix;
	if (-f $dist_file) {
		my $stree = $pm->compute_tree($dist_file);
		print STDERR  "Tree = ", $stree->{tree}, "\t", $stree->{tree_file}, $/;
	}
	
}

if ($action eq 'blast') {
	print "------------------------------------\n";
	
	print STDERR  "BLAST\n", $/;
	my $seq_id = shift;
	my $seq;
	unless ($seq_id && $seq_id =~ /^\d+$/) {
		print STDERR  "Sequence id (integer) is missging (last argument)", $/;
		exit 1;
	}
	else {
		($seq) = DNALC::Pipeline::Phylogenetics::DataSequence->search(
				project_id => $proj_id,
				id => $seq_id,
			);	
	}

	unless ($seq) {
		print STDERR  "Error: Sequence <$seq_id> not found!\n";
		exit 1;
	}

	my $st = $pm->do_blast_sequence(type => 'sequence', seq => $seq);
	if ($st->{status} eq 'success') {
		my $blast = $st->{blast};
		$st = $pm->add_blast_data($st->{blast}->id);
	}	
	print STDERR Dumper( $st ), $/;
}
