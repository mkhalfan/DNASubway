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

	my ($status, $msg, $realign) = ('error', '', $args->{realign} || 0);

	my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($args->{pid});
	my $proj = $pm->project;
	unless ($proj && $proj->user_id == $args->{user_id}) {
		$msg = "Project not found!";
		print STDERR  "Project not found!", $/;
	}
	else {
		if ($pm->build_alignment($realign)) {
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
    my $bail_out = sub { return nfreeze {status => 'error', 'message' => shift } };

    my $gbm = DNALC::Pipeline::App::Phylogenetics::GBManager->new;

    # Run create_dir (doesn't return anything)
    $gbm->create_dir($id);

    # Run create_fasta
    my $st = $gbm->create_fasta($id);

    # Run create_smt
    if ($st->{status} eq 'success'){
        $st = $gbm->create_smt($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }

    # Run make_template
    if ($st->{status} eq 'success'){
        $st = $gbm->make_template($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }
 # Run run_tbl2asn
    if ($st->{status} eq 'success'){
        $st = $gbm->run_tbl2asn($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }

    # Run prep_trace_file
    if ($st->{status} eq 'success'){
        $st = $gbm->prep_trace_file($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }

    # Run prep_submission_file
    if ($st->{status} eq 'success'){
        $st = $gbm->prep_submission_file($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }

    # Run submit
     if ($st->{status} eq 'success'){
        $st = $gbm->submit($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }
 # Run validate_submission
    if ($st->{status} eq 'success'){
        $st = $gbm->validate_submission($id);
    }
    else {
        return $bail_out->("ID: $id ERROR: $st->{message}");
    }

    # This is the sequence
    #$gmb->create_dir($id);
    #$gbm->create_fasta($id);
    #$gbm->create_smt($id);
    #$gbm->make_template($id);
    #$gbm->run_tbl2asn($id);
    #$gbm->prep_trace_file($id);
    #$gbm->prep_submission_file($id);
    #$gbm->submit($id);
    #$gbm->validate_submission($id);

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
