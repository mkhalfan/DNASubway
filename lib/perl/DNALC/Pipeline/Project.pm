package DNALC::Pipeline::Project;

use strict;
use warnings;

use POSIX ();
use File::Path;

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

use Class::DBI::Plugin::AbstractCount;
use Class::DBI::Plugin::Pager;

__PACKAGE__->table('project');
__PACKAGE__->columns(Primary => qw/project_id/);
__PACKAGE__->columns(Essential => qw/user_id name organism common_name 
								clade sample crc sequence_length created/);
__PACKAGE__->sequence('project_project_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{sample} ||= '';
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

#-----------------------------------------------------------------------------

sub group {
	warn "To be removed", $/;
	return shift()->clade;
}

#---------------------------------------------------

1;
