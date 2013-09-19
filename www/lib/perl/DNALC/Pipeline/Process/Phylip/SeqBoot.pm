package DNALC::Pipeline::Process::Phylip::SeqBoot;

use base 'DNALC::Pipeline::Process';
use File::chdir;
use File::Copy;
use Time::HiRes qw/gettimeofday tv_interval/;

use strict;

{
	sub new {
		my ($class, $project_dir) = @_;

		my $self = __PACKAGE__->SUPER::new('PHY_SEQBOOT', $project_dir);

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

		unless ($params{bootstraps}) {
			print STDERR  "Bootstrap number is missing", $/;
			return -1;
		}

		local $CWD = $self->{work_dir};

		#set input
		unless (copy $input_file, File::Spec->catfile($self->{work_dir}, $self->{conf}->{input_file})) {
			print STDERR  "Unable to copy input file to work dir: $self->{work_dir}", $/;
			return;
		}

		# set params
		my $instring = sprintf($self->{conf}->{menu_options}, $params{bootstraps});
		print STDERR "About to send parameters:\n", $instring if $debug;

		my ($stdout_file, $stderr_file);
		$stdout_file = File::Spec->catfile($self->{work_dir}, 'stdout.txt');
		$stderr_file = File::Spec->catfile($self->{work_dir}, 'stderr.txt');

		# run
		my $t0 = [gettimeofday];

		open OLDOUT, '>&', \*STDOUT or die "Can't dup STDOUT: $!";
		open OLDERR, '>&', \*STDERR or die "Can't dup STDERR: $!";
		open STDOUT, '>', $stdout_file 
					or die "Can't dup STDOUT to $stdout_file: $!";
		open STDERR, '>', $stderr_file 
					or die "Can't dup STDERR to $stderr_file: $!";

		open(PROGRAM,"|" . $self->{conf}->{program});
		print PROGRAM $instring;
		close PROGRAM;

		close STDOUT;
		close STDERR;
		open STDOUT, '>&', \*OLDOUT;
		open STDERR, '>&', \*OLDERR;

		my $outfile = File::Spec->catfile($self->{work_dir}, $self->{conf}->{output_file});
		if (-e $outfile) {
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);
			$self->{exit_status} = 0;
			print STDERR  "Outfile: ", $outfile, $/ if $debug;
		}
		else {
			$self->{exit_status} = 1;
		}

		return 0;
	}

	sub get_output {
		my ($self) = @_;
		if ($self->{exit_status} == 0) {
			my $file = File::Spec->catfile($self->{work_dir}, $self->{conf}->{output_file});
			return $file if -e $file;
		}
		return;
	}
}

1;
