package DNALC::Pipeline::Process;

use strict;
use DNALC::Pipeline::Config ();
use File::Path;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use Carp;


# runs processes
{

	sub new {
		my ($class, $task_name, $project_dir) = @_;

		unless (-e $project_dir) {
			carp "Project's dir not created: $project_dir?!\n";
			return;
		}

		my $self = bless {}, $class;
		$self->{type} = $task_name;
	
		my $config = DNALC::Pipeline::Config->new;
		my $pcf = $config->cf($task_name);
		unless ($pcf) {
			return;
		}
		if (! -x $pcf->{program} ) {
			print STDERR "Program [$pcf->{program}] not found!", $/;
			return;
		}
		$self->{conf} = $pcf;
		$self->_setup($project_dir);

		return unless $self->{work_dir};

		$self;
	}

	sub _setup {
		my ($self, $project_dir) = @_;

		my $dir = $project_dir . '/' . $self->{type};
		print "work dir = ", $dir, $/;

		if (-e $dir) {
			# should we remove the folder?
			warn "Must RM working folder? ", $dir, $/;
		}

		unless (-e $dir) {
			eval { mkpath($dir) };
			# what should happen if I can't create this dir?
			if ($@) {
				print STDERR "Couldn't create $dir: $@\n";
			}
		}
		# FIXME - find another place to initialize this
		$self->{work_dir} = $dir;

		if ($self->{conf}->{output_dir}) {
			$self->{conf}->{output_dir} = $self->{work_dir} . '/' . $self->{conf}->{output_dir};
			unless (-e $self->{conf}->{output_dir}) {
				mkpath($self->{conf}->{output_dir});
			}
			#print STDERR  "out dir = ", $self->{conf}->{output_dir}, $/;
			if (defined $self->{conf}->{option_output_dir}) {
				my $opt_dir = delete $self->{conf}->{option_output_dir};
				if ($self->{conf}->{option_glue}) {
					push @{$self->{conf}->{options}}, 
						$opt_dir . $self->{conf}->{option_glue} . 
						$self->{conf}->{output_dir};
				}
				else {
					push @{$self->{conf}->{options}}, (
							$opt_dir, $self->{conf}->{output_dir}
						);
				}
			}
		}

	}

	# FIXME split this into 2 functions.. _prepare() and run()
	sub run {
		my ($self, %params) = @_;

		my $pretend = exists $params{pretend} ? delete $params{pretend} : undef;
		my $input_file = $params{input} ? delete $params{input} : undef;
		my $debug = $params{debug} ? delete $params{debug} : $pretend;


		#print STDERR Dumper( \%params ), $/;
		unless ($input_file) {
			print STDERR 'Input file is missing...', $/;
			return -1;
		}

		my @opts = ($self->{conf}->{program});
		if ($self->{conf}->{options}) {
			push @opts, @{$self->{conf}->{options}};
		}

		# take extra params and check if we find them in the config file
		my $option_glue = $self->{conf}->{option_glue} || undef;
		for (keys %params) {
			if (defined $params{$_} && exists $self->{conf}->{$_}) {
				if (defined $option_glue) {
					push @opts, $self->{conf}->{$_} . $option_glue . $params{$_};
				}
				else {
					push @opts, ($self->{conf}->{$_},  $params{$_});
				}
			}
		}
		push @opts, $input_file;

		$self->{cmd} = join ' ', @opts;
		if ($debug) {
			print STDERR Dumper( \@opts ), $/;
		}

		unless ($pretend) {
			my ($stdout_file, $stderr_file);
			$stdout_file = $self->{work_dir} . '/' . 'stdout.txt';
			$stderr_file = $self->{work_dir} . '/' . 'stderr.txt';

			open OLDOUT,'>&', \*STDOUT or die "Can't dup STDOUT: $!";
			open OLDERR, '>&', \*STDERR or die "Can't dup STDERR: $!";
			open STDOUT, '>', $stdout_file 
						or die "Can't dup STDOUT to $self->{work_dir}: $!";
			open STDERR, '>', $stderr_file 
						or die "Can't dup STDERR to $self->{work_dir}: $!";

			# get the time it too this process to run
			my $t0 = [gettimeofday];

			system(@opts);

			$self->{exit_status} = $?;
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);

			close STDOUT;
			close STDERR;
			open STDOUT, '>&', \*OLDOUT;
			open STDERR, '>&', \*OLDERR;

			return $self->{exit_status};
		}
		return;
	}
}

1;
