package DNALC::Pipeline::SampleSource;

use strict;
use warnings;

use POSIX ();
use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('sample_source');
__PACKAGE__->columns(Primary => qw/src_id/);
__PACKAGE__->columns(Essential => qw/src_sample_id src_name src_release segment start stop url/);
__PACKAGE__->columns(Other => qw/created updated/);

__PACKAGE__->sequence('sample_source_src_id_seq');

__PACKAGE__->has_a(sample => 'DNALC::Pipeline::SampleSource');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
    $_[0]->{updated} ||= $_[0]->{created};
});

__PACKAGE__->add_trigger(before_update => sub {
    $_[0]->{updated} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


#--------------------------------
sub samplexxx {
	my ($self) = @_;
	return $self->src_sample_id;
}

1;
