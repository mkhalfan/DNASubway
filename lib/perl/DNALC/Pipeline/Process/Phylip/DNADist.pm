package DNALC::Pipeline::Process::Phylip::DNADist;

use base 'DNALC::Pipeline::Process';
use File::chdir;
use File::Copy;
use Capture::Tiny qw/capture/;
use Time::HiRes qw/gettimeofday tv_interval/;

use strict;

{
	sub new {
		my ($class, $project_dir) = @_;

		my $self = __PACKAGE__->SUPER::new('PHY_DNADIST', $project_dir);

		return $self;
	}

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

		local $CWD = $self->{work_dir};

		#set input
		unless (copy $input_file, File::Spec->catfile($self->{work_dir}, $self->{conf}->{input_file})) {
			print STDERR  "Unable to copy input file to work dir: $self->{work_dir}", $/;
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

		print STDERR "Sent parameters:\n", $instring if $debug;
		my $treefile = File::Spec->catfile($self->{work_dir}, $self->{conf}->{tree_file});
		if (-e $treefile) {
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);
			$self->{exit_status} = 0;
			print STDERR  "Tree file: ", $treefile, $/ if $debug;
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

	sub get_output {
		my ($self) = @_;
		if ($self->{exit_status} == 0) {
			my $tree = File::Spec->catfile($self->{work_dir}, $self->{conf}->{output_file});
			return $tree if -e $tree;
		}
		return;
	}
}

1;
