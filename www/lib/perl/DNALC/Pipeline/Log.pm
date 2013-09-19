package DNALC::Pipeline::Log;

use Log::Dispatch::Config();
use DNALC::Pipeline::Config ();

{
	my $logger;
	my $_init_done = undef;

	sub new {
		my ($class, $log_conf) = @_;


		$class->init($log_conf) unless $_init_done;
		unless ($logger) {
			$logger = bless {_logger => Log::Dispatch::Config->instance}, $class;
		}
		return $logger;
	}

	sub init {
		my ($class, $log_conf) = @_;
		unless ($log_conf) {
			my $config = DNALC::Pipeline::Config->new->cf('LOG');
			$log_conf = $config->{LOG_CONF};
		}

		if (-f $log_conf) {
			Log::Dispatch::Config->configure($log_conf);
		}

		$_init_done = 1;
	}

	sub log {
		my ($self, $level, $message) = @_;

		$self->{_logger}->log(level => $level, message => $message);
	}

	sub debug {
		my ($self, $message) = @_;
		$self->log('debug', $message);
	}
	sub info {
		my ($self, $message) = @_;
		$self->log('info', $message);
	}
	sub notice {
		my ($self, $message) = @_;
		$self->log('notice', $message);
	}
	sub warning {
		my ($self, $message) = @_;
		$self->log('warning', $message);
	}
	sub error {
		my ($self, $message) = @_;
		$self->log('error', $message);
	}

	sub emergency {
		my ($self, $message) = @_;
		$self->log('emergency', $message);
	}
}

1;
