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
__PACKAGE__->columns(Essential => qw/user_id name organism common_name description
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

__PACKAGE__->set_sql( check_organism => q{
		SELECT DISTINCT organism, common_name 
		FROM __TABLE__
		WHERE user_id = ?
			AND (common_name = ? OR organism = ?)
	});

sub get_used_organisms {
	my ($class, $params) = @_;
	unless ($params->{organism} && $params->{common_name} && $params->{user_id}) {
		print STDERR  "Project::check_organism: Invalid arguments..", $/;
		return;
	}
	my @data = ();
	my $sth = $class->sql_check_organism;
	$sth->execute($params->{user_id}, $params->{common_name}, $params->{organism});
	while (my $res = $sth->fetchrow_hashref) {
		push @data, $res;
	}
	return @data;
}

sub master_project {
	my ($mp) = DNALC::Pipeline::MasterProject->search(project_id => $_[0], project_type => 'annotation');
	return $mp;
}

1;
