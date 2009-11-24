package DNALC::Pipeline::ProjectLogger;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use Params::Validate qw(:types);
use Carp;
use Data::Dumper;

__PACKAGE__->table('project_log');
__PACKAGE__->columns(Primary => qw/log_id/);
__PACKAGE__->columns(Essential => qw/project_id user_id type message created/);
__PACKAGE__->sequence('project_log_log_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

sub log {
	my $self = shift;

	my %o = Params::Validate::validate(@_, {
		user_id => { type => SCALAR, default => '0' },
		project_id => { type => SCALAR, default => '0' },
		type => { type => SCALAR, 
					default => 'INFO',
					regex => qr/^(?:NOTE|ERR|WARN|INFO|DEBG)$/,
		},
		message => { type => SCALAR },
	}); 
	__PACKAGE__->create({
			user_id => $o{user_id},
			project_id => $o{project_id},
			type => $o{type},
			message => $o{message},
		});
}

__PACKAGE__->set_sql(latest => q{
		SELECT *
		FROM __TABLE__
		WHERE project_id = ?
		ORDER BY created DESC
		LIMIT 2
	});
__PACKAGE__->set_sql(all => q{
		SELECT *
		FROM __TABLE__
		WHERE project_id = ?
		ORDER BY created DESC
	});


1;

__END__
package main;
use Data::Dumper;
my $log = DNALC::Pipeline::ProjectLogger->new;
print STDERR Dumper( $log->log(
		user_id => 54,
		project_id => 652,
		type => 'INFO',
		message => 'test'
	)), $/;
