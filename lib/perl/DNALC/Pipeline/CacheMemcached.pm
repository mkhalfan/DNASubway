package DNALC::Pipeline::CacheMemcached;

use DNALC::Pipeline::Config ();
use Cache::Memcached ();

use Readonly;

Readonly::Scalar  my $timeout => 1 * 60 * 60; # 1 hr

sub new {
	my ($class) = @_;
	my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
	my $mc = Cache::Memcached->new ({
			servers => $pcf->{MEMCACHED_SERVERS},
			debug => 0,
		});

	bless {
			_mc => $mc
		}, __PACKAGE__;
}

sub get {
	my ($self, $key) = @_;
	$self->{_mc}->get($key);
}

sub set {
	my ($self, $key, $value, $tout) = @_;
	$tout ||= $timeout;
	$self->{_mc}->set($key, $value, $tout);
}

1;
