package DNALC::Pipeline::Feedback;

use base qw(DNALC::Pipeline::DBI);

use POSIX ();

__PACKAGE__->table('feedback');
__PACKAGE__->columns(Primary => qw/feedback_id/);
__PACKAGE__->columns(Essential => qw/name email category created/);
__PACKAGE__->columns(Other => qw/comment/);

__PACKAGE__->sequence('feedback_feedback_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


