package DNALC::Pipeline::Process::Phylip::DNADist;

use base 'DNALC::Pipeline::Process';
use File::chdir;
use File::Copy;
#use Capture::Tiny qw/capture tee/;
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

		#my ($stdout, $stderr) = capture {
			open(PROGRAM,"|" . $self->{conf}->{program});
			print PROGRAM $instring;
			close PROGRAM;
		#};
		close STDOUT;
		close STDERR;
		open STDOUT, '>&', \*OLDOUT;
		open STDERR, '>&', \*OLDERR;

		$self->{elapsed} = tv_interval($t0, [gettimeofday]);

		my $outfile = File::Spec->catfile($self->{work_dir}, $self->{conf}->{output_file});
		if (-f $outfile) {
			$self->{exit_status} = 0;
			print STDERR  "Dist file: ", $outfile, $/ if $debug;
		}
		else {
			$self->{exit_status} = 1;
		}
		#my $stdout_file = 'stdout.txt';
		#my $stderr_file = 'stderr.txt';
	
		#my $fh = IO::File->new;
		#if ($stdout && $fh->open($stdout_file, 'w')) {
		#	print $fh $stdout;
		#	$fh->close;
		#}
		#if ($stderr && $fh->open($stderr_file, 'w')) {
		#	print $fh $stderr;
		#	$fh->close;
		#}

		return 0;
	}

	sub get_output {
		my ($self) = @_;
		if ($self->{exit_status} == 0) {
			my $f = File::Spec->catfile($self->{work_dir}, $self->{conf}->{output_file});
			return $f if -e $f;
		}
		return;
	}
}

1;
