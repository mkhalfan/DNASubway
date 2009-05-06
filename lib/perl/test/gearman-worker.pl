#!/usr/bin/perl 

use strict;
use lib "/var/www/lib/perl";
use DNALC::Pipeline::Process::Augustus ();
use DNALC::Pipeline::Process::RepeatMasker ();
use DNALC::Pipeline::Process::TRNAScan ();
use DNALC::Pipeline::Process::FGenesH ();

use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();

use Data::Dumper;
use Gearman::Worker ();
use Storable qw(freeze);

sub run_aug {
   my $gearman = shift;
   my $WD = $gearman->arg;
   my $augustus = DNALC::Pipeline::Process::Augustus->new( $WD  );
   if ( $augustus) {
        $augustus->run(
                        input => $WD . '/augustus.fa',
                        output_file => $WD . '/AUGUSTUS/' . 'augustus.gff3',
                        pretend => 0,
                );
        if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
                print "AUGUSTUS: success\n";
	       	my $gff_file = $augustus->get_gff3_file;
        	print 'AUGUSTUS: gff_file: ', $gff_file, $/;
                return 0;
        }
        else {
              	print "AUGUSTUS: fail\n";
                return 1;
        }        
   }
}

sub run_augustus {
	
	my $gearman = shift;
	my $wd = $gearman->arg;
	return unless -d $wd;

	my $status = { success => 0 };

	my $augustus = DNALC::Pipeline::Process::Augustus->new( $wd );
	if ( $augustus) {
		my $pretend = 0;
		$augustus->run(
				input => $wd . '/fasta.fa',
				output_file => $augustus->{work_dir} . '/' . 'augustus.gff3',
				pretend => $pretend,
			);
		if (defined $augustus->{exit_status} && $augustus->{exit_status} == 0) {
			print STDERR "AUGUSTUS: success\n";

			$status->{success} = 1;
			$status->{elapsed} = $augustus->{elapsed};
			$status->{gff_file}= $augustus->get_gff3_file;
			#$self->set_status('augustus', 'Done', $augustus->{elapsed});
		}
		else {
			print STDERR "AUGUSTUS: fail\n";
			#$self->set_status('augustus', 'Error', $augustus->{elapsed});
		}
		print STDERR 'AUGUSTUS: duration: ', $augustus->{elapsed}, $/;
	}
	return freeze $status;
}
#-------------------------------------------------------------------------

sub run_repeatmasker {
	my $gearman = shift;
	my $wd = $gearman->arg;

	return unless -d $wd;

	my $status = { success => 0 };

	my $rep_mask = DNALC::Pipeline::Process::RepeatMasker->new( $wd  );
	if ($rep_mask) {
		my $pretend = 0;
		$rep_mask->run(
				input => $wd . '/fasta.fa',
				pretend => $pretend,
				debug => 1,
			);
		if (defined $rep_mask->{exit_status} && $rep_mask->{exit_status} == 0) {
			print STDERR "REPEAT_MASKER: success\n";
			$status->{success} = 1;
			$status->{elapsed} = $rep_mask->{elapsed};
			$status->{gff_file}= $rep_mask->get_gff3_file;
			#$self->set_status('repeat_masker', 'Done', $rep_mask->{elapsed});
		}
		else {
			print STDERR "REPEAT_MASKER: fail\n";
			#$self->set_status('repeat_masker', 'Error', $rep_mask->{elapsed});
		}
		print STDERR 'RM: duration: ', $rep_mask->{elapsed}, $/ if $rep_mask->{elapsed};
	}
	return freeze $status;
}

sub run_trnascan {
   my $gearman = shift;
   my ($pid, $task) = split /,\s?/, $gearman->arg;
   my $proj = DNALC::Pipeline::Project->retrieve( $pid );
   return unless $proj;

   my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );
   my $st = $wfm->run_trna_scan;
   return freeze $st;
}

sub run_fgenesh {
   my $gearman = shift;
   my $wd = $gearman->arg;
   return unless -d $wd;

	my $status = { success => 0 };

	my $fgenesh = DNALC::Pipeline::Process::FGenesH->new( $wd, 'Monocots' );
	if ( $fgenesh) {
		my $pretend = 0;
		$fgenesh->run(
				input => $wd . '/fasta.fa',
				pretend => $pretend,
				debug => 0,
			);
		if (defined $fgenesh->{exit_status} && $fgenesh->{exit_status} == 0) {
			print STDERR "FGENESH: success\n";

			$status->{success} = 1;
			$status->{elapsed} = $fgenesh->{elapsed};
			$status->{gff_file}= $fgenesh->get_gff3_file;
			#$self->set_status('fgenesh', 'Done', $fgenesh->{elapsed});
		}
		else {
			print STDERR "FGENESH: fail\n";
			#$self->set_status('fgenesh', 'Error', $fgenesh->{elapsed});
		}
		print STDERR 'FGENESH: duration: ', $fgenesh->{elapsed}, $/;
	}
	#print STDERR Dumper( $status ), $/;
	return freeze $status;
}

my $worker = Gearman::Worker->new;
$worker->job_servers('localhost');
#$worker->register_function("augustus", \&run_aug);
$worker->register_function("augustus", \&run_augustus);
$worker->register_function("repeat_masker", \&run_repeatmasker);
$worker->register_function("trna_scan", \&run_trnascan);
$worker->register_function("fgenesh", \&run_fgenesh);

$worker->work while 1;
