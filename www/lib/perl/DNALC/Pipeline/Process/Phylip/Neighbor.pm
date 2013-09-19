package DNALC::Pipeline::Process::Phylip::Neighbor;

use base 'DNALC::Pipeline::Process';
use File::chdir;
use File::Copy;
use File::Slurp qw/read_file write_file/;
use Time::HiRes qw/gettimeofday tv_interval/;

use strict;

{
	sub new {
		my ($class, $project_dir) = @_;

		my $self = __PACKAGE__->SUPER::new('PHY_NEIGHBOR', $project_dir);

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
		if ($params{bootstraps}) {
			$instring = sprintf($self->{conf}->{menu_options_wb}, $params{bootstraps});
		}
		if ($params{input_is_protein}) {
			$instring =~ s/[LR]\n//;
		}
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

		my $treefile = File::Spec->catfile($self->{work_dir}, $self->{conf}->{tree_file});
		if (-e $treefile) {
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);
			$self->{exit_status} = 0;
			print STDERR  "Tree file: ", $treefile, $/ if $debug;

			# fix negative branches in the tree		
			my $neg_len_rx = qr/:-\d+\.?\d*?/;

			my $tree_data = read_file($treefile);
			if ($tree_data && $tree_data =~ /$neg_len_rx/) {
				# make a copy
				my $treefile_copy = $treefile . '_copy';
				copy $treefile, $treefile_copy;

				$tree_data =~ s/$neg_len_rx/:0.0/g;
				write_file($treefile, $tree_data);
			}

		}
		else {
			$self->{exit_status} = 1;
		}

		return 0;
	}

	sub get_tree {
		my ($self) = @_;
		if ($self->{exit_status} == 0) {
			my $tree = File::Spec->catfile($self->{work_dir}, $self->{conf}->{tree_file});
			return $tree if -e $tree;
		}
		return;
	}

	sub get_output {
		
	}
}

1;
