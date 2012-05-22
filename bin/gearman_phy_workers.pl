#!/usr/bin/perl 

use strict;
use lib ("/var/www/lib/perl", "/home/gearman/dnasubway/lib/perl");

use Gearman::Worker ();
use Storable qw(nfreeze thaw);

use DNALC::Pipeline::App::Phylogenetics::ProjectManager ();
use DNALC::Pipeline::App::Phylogenetics::GBManager ();
use DNALC::Pipeline::Process::Phylip::SeqBoot ();
use DNALC::Pipeline::Process::Phylip::DNADist ();
use DNALC::Pipeline::Process::Phylip::ProtDist ();
use DNALC::Pipeline::Process::Phylip::DNAMl ();
use DNALC::Pipeline::Process::Phylip::ProMl ();
use DNALC::Pipeline::Process::Phylip::Neighbor ();
use DNALC::Pipeline::Process::Phylip::Consense ();
use DNALC::Pipeline::Config();
use File::Basename;
use Data::Dumper;
use Image::LibRSVG ();
use File::chdir;


sub run_build_tree {
	my $gearman = shift;
	my $args = thaw( $gearman->arg );

	my ($status, $msg) = ('error', '');

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj && $proj->user_id == $args->{user_id}) {
		$msg = "Project not found!";
		print STDERR  "Project not found!", $/;
	}
	else {

		my $tree_type = $args->{tree_type} || 'NJ';
		my $pwd = $pm->work_dir;
		my $alignment = my $input = $pm->get_alignment('phyi');
		my ($tree, $tb);

		if (-f $input) {

			if ($tree_type eq 'ML') {
				$tb = $proj->type ne 'protein'
						? DNALC::Pipeline::Process::Phylip::DNAMl->new($pwd)
						: DNALC::Pipeline::Process::Phylip::ProMl->new($pwd);
			}
			else {
				# compute distance
				my $d;

				$d = $proj->type ne 'protein'
						? DNALC::Pipeline::Process::Phylip::DNADist->new($pwd)
						: DNALC::Pipeline::Process::Phylip::ProtDist->new($pwd);
				$d->run(input => $input, debug => 0);
				$input = $d->get_output;

				$tb = DNALC::Pipeline::Process::Phylip::Neighbor->new($pwd);

			}

			if ($tb) {
				$tb->run(input => $input, debug => 0, input_is_protein => $proj->type eq 'protein');
				$tree = $tb->get_tree;

				my $stree = $pm->_store_tree($tree, $tree_type, $alignment) if -f $tree;

				if (-s $stree->{tree_file}) {
					if ($tree_type eq 'ML') {
						$pm->set_task_status("phy_tree_ml", "done", $tb->{elapsed});
					}
					else {
						$pm->set_task_status("phy_tree", "done", $tb->{elapsed});
					}
					$status = "success";
				}
				
				## Get current nw tree and store the name of this file (to create a svg and png of the same name)
				## (we are actually saving the complete file path minus the .nw extension in this variable, we'll
				## need the full path anyways)
				my $tree_id = $pm->get_tree($tree_type)->{tree_file};
				$tree_id =~ s/\.nw$//;

				## Determine number of sequences in tree so you can calculate an appropriate tree height
				open (FILE, $alignment) || die "Error: Unable to open alignment.phyi file: $!\n";
				my $first_line = <FILE>;
				close FILE;
				my $num_sequences = (split(' ', $first_line))[0];
				my $INDIVIDUAL_HEIGHT = 40;
				my $tree_height = $INDIVIDUAL_HEIGHT * $num_sequences;
				$tree_height = 200 if ($tree_height < 200);

				## Make the tree in SVG format			
				if ($status eq 'success') {
					unless (-e "/usr/local/TreeVector/source/TreeVector.jar") {
						$msg = "TreeVector file(s) are missing.";
						print STDERR "__FILE__: ", $msg;
						return nfreeze({status => 'error', msg => $msg});
					}

					if (system("java -jar /usr/local/TreeVector/source/TreeVector.jar " 
						. $pm->get_tree($tree_type)->{tree_file} . " -out $tree_id.svg -size 760 $tree_height") == 0) 
					{
						## Convert the SVG to a PNG
						my $rsvg = new Image::LibRSVG();
						$rsvg->convert("$tree_id.svg", "$tree_id.png");
					}
					else {
						$status = "error";
						$msg = "TreeVector Failed";
					}
				}	
				
			}
		}
	}

	return nfreeze({status => $status, msg => $msg});
}

sub run_build_tree_save {
	my $gearman = shift;
	my $args = thaw( $gearman->arg );

	my ($status, $msg) = ('error', '');

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj) {
		$msg = "Project not found!";
		print STDERR  "Project not found!", $/;
	}
	else {

		my $phy_cfg = DNALC::Pipeline::Config->new->cf('PHYLOGENETICS');
		my $bootstrap_num = $phy_cfg->{BOOTSTRAPS} || 0;
		$bootstrap_num = $bootstrap_num / 10 if ($bootstrap_num && $proj->type eq 'protein');

		my $pwd = $pm->work_dir;
		my $input = $pm->get_alignment('phyi');
		print STDERR "Alignment file to use: $input\n";

		if (-f $input) {
			my $s = DNALC::Pipeline::Process::Phylip::SeqBoot->new($pwd);
			$s->run(input => $input, bootstraps => $bootstrap_num);
			$input = $s->get_output;

			if ($proj->type ne 'protein') {
				my $d = DNALC::Pipeline::Process::Phylip::DNADist->new($pwd);
				$d->run(input => $input, debug => 0, bootstraps => $bootstrap_num);
				$input = $d->get_output;
			}
			else {
				my $d = DNALC::Pipeline::Process::Phylip::ProtDist->new($pwd);
				$d->run(input => $input, debug => 0, bootstraps => $bootstrap_num);
				$input = $d->get_output;
			}

			my $n = DNALC::Pipeline::Process::Phylip::Neighbor->new($pwd);
			$n->run(input => $input, debug => 0, bootstraps => $bootstrap_num, 
					input_is_protein => $proj->type eq 'protein');
			$input = $n->get_tree;

			my $c = DNALC::Pipeline::Process::Phylip::Consense->new($pwd);
			$c->run(input => $input, debug => 0);
			my $stree = $pm->_store_tree($c->get_tree);

			print STDERR  "Tree = ", $stree->{tree}, "\t", $stree->{tree_file}, $/;
			$pm->set_task_status("phy_tree", "done");
			$status = "success";
		}
	}

   return nfreeze({status => $status, msg => $msg});
}

sub run_phylip {
	my $gearman = shift;
	my $args = thaw( $gearman->arg );

	my ($status, $msg) = ('error', '');

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj) {
		$msg = "Project not found!";
		print STDERR  "Project not found!", $/;
	}
	else {
		#my $phyi_file = $pm->get_alignment('phyi');
		#print STDERR "Alignment file to use: $phyi_file\n";

		my $dist_file = $pm->compute_dist_matrix;
		#print STDERR "Dist matrix file to use: $dist_file\n";
		if (-f $dist_file) {
			#print STDERR  "Dist = ", $dist_file, "\tsize = ", -s $dist_file, $/;

			my $stree = $pm->compute_tree($dist_file);
			print STDERR  "Tree = ", $stree->{tree}, "\t", $stree->{tree_file}, $/;
			$pm->set_task_status("phy_tree", "done");
			$status = "success";
		}
	}

   return nfreeze({status => $status, msg => $msg});
}


sub run_muscle {
	my $gearman = shift;
	my $args = thaw( $gearman->arg );

	my ($status, $msg, $realign, $trim) = ('error', '', $args->{realign} || 0, $args->{trim} || 0);

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj && $proj->user_id == $args->{user_id}) {
		$msg = "Project not found!";
		print STDERR  "Project not found!", $/;
	}
	else {
		if ($pm->build_alignment($realign, $trim)) {
			$status = "success";
		}
	}

   return nfreeze({status => $status, msg => $msg});
}

sub run_gb_submit {
    my $gearman = shift;
    my $args = thaw( $gearman->arg );
    my $id = $args->{id};

    #my ($status, $msg) = ('error', '');
	#my $bail_out = sub { return nfreeze {status => 'error', 'message' => shift } };

    my $gbm = DNALC::Pipeline::App::Phylogenetics::GBManager->new;
	my $st = $gbm->run($id);
	#print STDERR 'RESPONSE FROM GBManager->run is: ', $st->{status}, $/;
	return nfreeze({status => $st->{status}, message => $st->{message}});
}

sub run_merger {
	my $gearman = shift;
	my $args = thaw( $gearman->arg );

	my ($status, $msg) = ("error", "");

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj && $proj->user_id == $args->{user_id}) {
		$msg = "Project not found.";
		print STDERR  "Project [$args->{pid}] not found!", $/;
	}
	else {
		my @pairs = $pm->pairs;
		if (@pairs) {
			for my $p (@pairs) {
				next if $p->consensus;
				$pm->build_consensus($p);
			}
			$pm->set_task_status("phy_consensus", "done");
			$status = "success";
			$msg = $pm->get_task_status('phy_consensus')->name;
		}
		else {
			#if ($pm->get_task_status("phy_consensus")->name eq "done") {
			#	$pm->set_task_status("phy_consensus", "not-processed");
			#}
			$msg = "This project has no pairs!";
		}

	}

   return nfreeze({status => $status, message => $msg});
}

#-------------------------------------------------
my $script_name = fileparse($0);
$script_name =~ s/\.[^.]*$//;
my $work_exit = 0;
my ($is_idle, $last_job_time);

my $stop_if = sub { 
	($is_idle, $last_job_time) = @_; 

	if ($work_exit) { 
		print STDERR  "*** [$script_name] exiting.. \n", $/;
		return 1; 
	}
	return 0; 
}; 

#-------------------------------------------------

$CWD = "/";
my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
my $worker = Gearman::Worker->new;
$worker->job_servers(@{$pcf->{GEARMAN_SERVERS}});
$worker->register_function("phy_alignment", \&run_muscle);
#$worker->register_function("phy_tree", \&run_phylip);
$worker->register_function("phy_tree", \&run_build_tree);
$worker->register_function("phy_consensus", \&run_merger);
$worker->register_function("phy_gb_submit", \&run_gb_submit);
$worker->register_function("${script_name}_exit" => sub { 
	$work_exit = 1; 
});

$worker->work( stop_if => $stop_if ) while !$work_exit;

exit 0;
