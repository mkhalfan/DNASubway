#!/usr/bin/perl 

use common::sense;

use FindBin;
use lib "$FindBin::Bin/..";
use DNALC::Pipeline::Phylogenetics::Project ();
use DNALC::Pipeline::App::Phylogenetics::ProjectManager ();
use Getopt::Long;

use Data::Dumper;


my ($PID, $ACTION);
GetOptions(
  'pid=i'		=> \$PID,
  'action=s'	=> \$ACTION,
);

my ($proj, $pm, $data_src);

my %actions = (
		add => 1,
		display => 1,
		merge_pairs => 1,
		align => 1,
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
		my @files = </home/cornel/tmp/paiwisealignment/fasta/*>;
		#print STDERR "files to add = ", scalar (@files), $/;
		$pm->add_data({
			source => "upload",
			files => \@files,
			type => "fasta",
		});
	}
	if (1) {
		my @files = </home/cornel/tmp/paiwisealignment/sequences/*.ab1>;
		#print STDERR "files to add = ", scalar (@files), $/;
		#print STDERR "files = ", Dumper(\@files), $/;
		#exit;
		$pm->add_data({
				source => "upload",
				files => \@files,
				type => "trace",
		});
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
		my $rc = $pm->build_concensus($p);
		print "build_concensus = ", $rc, $/;
		print STDERR  $p->concensus, $/;
		print STDERR  "---------------", $/;

	}	
}

#------------------------------------

if ($action =~ /add|display/) {

	if ($pm->has_fasta_file) {
		print STDERR "fasta = ", $pm->fasta_file, $/;
	}
	else {
		print STDERR "No fasta file for this project\n";
	}

	for (qw/fasta trace/) {
		my @files = $pm->files($_);
		if (@files) {
			print "$_ files: ", scalar(@files), $/;
			#print "files[0] seq = \n", $files[0]->seq, $/;
			if ($_ =~ /^trace$/i) {
				my @q = $files[0]->quality_values;
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

	# trim
	print $pm->trim_alignment({left => 30, right => 20});

	# realign
}
