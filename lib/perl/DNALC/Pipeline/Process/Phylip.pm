package DNALC::Pipeline::Process::Phylip;

use base 'DNALC::Pipeline::Process';
use File::chdir;
use File::Copy;
use Capture::Tiny qw/capture/;
use Time::HiRes qw/gettimeofday tv_interval/;

use strict;

{
	sub new {
		my ($class, $project_dir) = @_;

		my $self = __PACKAGE__->SUPER::new('PHY_NEIGHBOR', '/tmp');

		return $self;
	}

	#~/downloads/BioPerl-run-1.6.0-7pu4fn/Bio/Tools/Run/Phylo/Phylip/Neighbor.pm
	sub run {
	
		my ($self, %params) = @_;
		#remove old exit_status
		delete $self->{exit_status};

		my $pretend = exists $params{pretend} ? delete $params{pretend} : undef;
		my $input_file = $params{input} ? delete $params{input} : undef;
		my $debug = $params{debug} ? delete $params{debug} : $pretend;

		unless ($input_file) {
			print STDERR 'Input file is missing...', $/;
			return -1;
		}

		#print STDERR  $CWD, $/;
		local $CWD = $self->{work_dir};
		#print STDERR  $CWD, $/;

		#set input
		unless (copy $input_file, File::Spec->catfile($self->{work_dir}, $self->{conf}->{input_file})) {
			print STDERR  "Unable to copy input file to work dir: , $self->{work_dir}", $/;
			return;
		}

		# set params
		my $instring = $self->{conf}->{menu_options};

		# run
		my $t0 = [gettimeofday];
		my ($stdout, $stderr) = capture {
			open(PROGRAM,"|" . $self->{conf}->{program});
			print PROGRAM $instring;
			close PROGRAM;
		};

		my $treefile = File::Spec->catfile($self->{work_dir}, $self->{conf}->{tree_file});
		if (-e $treefile) {
			$self->{exit_status} = 0;
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);
		}
		else {
			$self->{exit_status} = 1;
		}
		my $stdout_file = 'stdout.txt';
		my $stderr_file = 'stderr.txt';
	
		my $fh = IO::File->new;
		if ($stdout && $fh->open($stdout_file, 'w')) {
			print $fh $stdout;
			$fh->close;
		}
		if ($stderr && $fh->open($stderr_file, 'w')) {
			print $fh $stderr;
			$fh->close;
		}

		return 0;
	}

	sub get_tree {
		my ($self) = @_;
		if ($self->{exit_status} == 0) {
			return File::Spec->catfile($self->{work_dir}, $self->{conf}->{tree_file});
		}
		return;
	}

	sub _set_input {
		
	}

	sub _run {
	
	}
}

1;
