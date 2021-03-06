package DNALC::Pipeline::Process;

use strict;
use DNALC::Pipeline::Config ();
use File::Path;
use Time::HiRes qw/gettimeofday tv_interval/;
use Data::Dumper;

use Carp;

{

	# 
	# constructor of the class 
	#
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

		# checks if file exists and it's executable
		if (! -x $pcf->{program} ) {
			print STDERR "Program [$pcf->{program}] not found!", $/;
			return;
		}
		$self->{conf} = $pcf;
		$self->_setup($project_dir);

		return unless $self->{work_dir};

		$self;
	}

	#
	# performs the setup of the Task/Run based on it's config file
	#
	sub _setup {
		my ($self, $project_dir) = @_;

		my $dir = $project_dir . '/' . $self->{type};
		#print STDERR "work dir = ", $dir, $/;

		# TODO : move these into a future ProjectManager module
		if (-e $dir) {
			my @old_files = <$dir/*>;
			foreach my $of (@old_files) {
				if (-f $of) {
					unlink $of;
				} elsif (-d $of) {
					for (<$of/*>) {
						unlink;
					}
					rmdir $of;
				}
			}
		}

		unless (-e $dir) {
			eval { mkpath($dir) };
			# what should happen if I can't create this dir?
			if ($@) {
				print STDERR "Couldn't create $dir: $@\n";
			}
		}
		$self->{work_options} = [ @{ $self->{conf}->{options} } ];
		# FIXME - find another place to initialize this
		$self->{work_dir} = $dir;

		if (defined $self->{conf}->{output_file} && defined $self->{conf}->{option_output_file}) {
			my $out_file = $self->{work_dir} . '/' . $self->{conf}->{output_file};
			my $opt_file = $self->{conf}->{option_output_file};
			if ($self->{conf}->{option_glue}) {
				push @{$self->{work_options}}, 
					$opt_file . $self->{conf}->{option_glue} . $out_file;
			}
			else {
				push @{$self->{work_options}}, (
						$opt_file, $out_file
					);
			}
		}
	}

	# this will generate the option to be passed to the pogram
	sub get_options {
		my ($self) = @_;
		my @opts = ();
		if ($self->{work_options}) {
			push @opts, @{$self->{work_options}};
		}

		return @opts;
	}

	#
	# executes the task/routine
	#
	# FIXME split this into 2 functions.. _prepare() and run()
	sub run {
		my ($self, %params) = @_;

		#remove old exit_status
		delete $self->{exit_status};

		my $pretend = exists $params{pretend} ? delete $params{pretend} : undef;
		my $input_file = $params{input} ? delete $params{input} : undef;
		my $input_files = $params{input_files} && 'ARRAY' eq ref $params{input_files}
						? delete $params{input_files} 
						: undef;
		my $debug = $params{debug} ? delete $params{debug} : $pretend;

		unless ($input_file || @$input_files) {
			print STDERR 'Input file(s) is/are missing...', $/;
			return -1;
		}

		my @opts = ($self->{conf}->{program});
		push @opts, $self->get_options;

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
		push @opts, $input_file if $input_file;
		push @opts, @$input_files if $input_files && @$input_files;

		$self->{cmd} = join ' ', @opts;
		if ($debug) {
			print STDERR 'OPTIONS: ', Dumper( \@opts ), $/;
		}

		unless ($pretend) {
			my ($stdout_file, $stderr_file);
			$stdout_file = $self->{work_dir} . '/' . 'stdout.txt';
			$stderr_file = $self->{work_dir} . '/' . 'stderr.txt';

			# get the time it too this process to run
			my $t0 = [gettimeofday];
			if ($self->{conf}->{redirect}) {
				my $cmd = join " ", @opts;
				print STDERR  "CMD = ", $cmd, $/ if $debug;

				system($cmd . ' > ' . $stdout_file);
				$self->{exit_status} = $?;
			}
			else {
				# retirect STDIN & STDOUT
				#
				open OLDOUT,'>&', \*STDOUT or die "Can't dup STDOUT: $!";
				open OLDERR, '>&', \*STDERR or die "Can't dup STDERR: $!";
				open STDOUT, '>', $stdout_file 
							or die "Can't dup STDOUT to $self->{work_dir}: $!";
				open STDERR, '>', $stderr_file 
							or die "Can't dup STDERR to $self->{work_dir}: $!";

				system(@opts);
				$self->{exit_status} = $?;

				close STDOUT;
				close STDERR;
				open STDOUT, '>&', \*OLDOUT;
				open STDERR, '>&', \*OLDERR;
			}
			$self->{elapsed} = tv_interval($t0, [gettimeofday]);

			return $self->{exit_status};
		}
		return;
	}
}

1;
