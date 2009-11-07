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

use DNALC::Pipeline::MasterProject ();
use Data::Dumper;

__PACKAGE__->table('project');
__PACKAGE__->columns(Primary => qw/project_id/);
__PACKAGE__->columns(Essential => qw/user_id name organism common_name 
								clade sample crc sequence_length created/);
__PACKAGE__->sequence('project_project_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{sample} ||= '';
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


__PACKAGE__->add_trigger(after_create => sub {
	my $mp = eval {
		DNALC::Pipeline::MasterProject->create({
				project_id => $_[0]->id,
				user_id => $_[0]->user_id,
				project_type => 'annotation'
			});
	};
	if ($@) {
		print STDERR  $@, $/;
	}
});

__PACKAGE__->add_trigger(before_delete => sub {
	my ($mp) = DNALC::Pipeline::MasterProject->search({
				project_id => $_[0]->{project_id},
				user_id => $_[0]->{user_id},
			});
	if ($mp) {
		$mp->delete;
	}
	else {
		print STDERR  "MasterP for project ", $_[0]->{project_id}, " not found.", $/;
	}
});


#---------------------------------------------------

1;
