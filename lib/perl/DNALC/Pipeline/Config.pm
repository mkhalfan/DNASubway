package DNALC::Pipeline::Config;
use strict;
use Carp ();
use File::Spec ();
use IO::File ();

{
	# base data structure containing cacheable configuration data
	# should look like:
	#  %CF = (
	#		  NAME1 => {
	#					 mtime => [configuration file modification time],
	#					 data  => { [configuration data] },
	#				   },
	#		  NAME2 => {
	#					 mtime => [configuration file modification time],
	#					 data  => { [configuration data] },
	#				   },
	#		);
	my %CF;

	# default configuration directory;
	#my $_def_cf_dir = '/home/cornel/projects/pipeline/lib/perl/config';
	my $_def_cf_dir = 'var/www/lib/perl/config';

	sub new {
		my ($class, $cfdir) = @_;
		$cfdir ||= $_def_cf_dir;
		opendir DH, $cfdir or Carp::croak "Cannot open directory '$cfdir': $!\n";
		closedir DH;
		bless \$cfdir, $class;
	}

	sub cf {
		my ($this, $name) = @_;
		my $file = File::Spec->catfile(${$this}, $name);
		my $mtime = (stat($file))[9];
		delete $CF{$name} if $!; # drop cached data if error stat-ing file!
		if (exists $CF{$name}) {				 ## check cache freshness
			if ($mtime <= $CF{$name}->{mtime}) { # cached data still fresh
				return $CF{$name}->{data};
			}
		}
		local $@; # keep it to ourselves!
		my $data = do $file;
		if ($@) {
			Carp::carp "ERROR loading configuration from '$file': $@\n";
			return;
		} elsif (!defined $data) {
			Carp::carp "ERROR loading configuration from '$file': $!\n";
			return;
		}
		$CF{$name} = { mtime => $mtime, data => $data };
		$data;
	}

}

1;

__END__

