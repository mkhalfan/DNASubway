package DNALC::Pipeline::NGS::Job;

use POSIX ();
use Data::Dumper;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/api_job_id project_id task_id user_id status_id deleted is_basic/);
__PACKAGE__->columns(Other => qw/duration created/);

__PACKAGE__->sequence('ngs_job_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');
__PACKAGE__->has_a(task_id => 'DNALC::Pipeline::Task');

__PACKAGE__->has_many(job_params => 'DNALC::Pipeline::NGS::JobParam');
__PACKAGE__->has_many(input_files => 'DNALC::Pipeline::NGS::JobInputFile');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});


sub _get_next_id {
	my $class = shift;
	$class->sql_next_id->select_val;
}

# alias for task_id
sub task {
	my ($self) = @_;
	return $self->task_id;
}

sub attrs {
	my ($self) = @_;
	my %data;
	for ($self->job_params) {
		$data{$_->name} = $_->value;
	}
	\%data;
}

sub set_params {
	my ($self, $api_job) = @_;

	my @stored_params = grep {$_->type eq ''} $self->job_params;

	for my $name (keys %$api_job) {
		next if $name =~ /^(?:id|inputs|parameters|owner|submitTime)$/;

		my $value = $api_job->{$name} || '';
		if (ref($value) eq 'ARRAY') {
			next if ref($value->[0]); # can't handle all situations
			$value = join ":", @$value;
		}
		my ($param) = grep {$_->name eq $name} @stored_params;
		if ($param) {
			if ($param->value ne $value) {
				#print STDERR  $param, ' ', $param->name, $/;
				$param->value($value);
				$param->update;
			}
		}
		else {
			# create new param
			$self->add_to_job_params({type => '', name => $name, value => $value});
		}
	}
	
}

sub status {
	my $self = shift;
	my %status_map = (
			"not-processed" => 1,
			"done"          => 2,
			"error"         => 3,
			"processing"    => 4
		);
	my %status_id_to_name = reverse %status_map;

	return $status_id_to_name{$self->{status_id}};
}

# AND task_id = (SELECT task_id FROM task WHERE name IN ('ngs_tophat'))
__PACKAGE__->set_sql(jobs_status => q{
			SELECT task.name AS task_name, task_status.name AS status_name, count(*) AS num
			FROM task 
			LEFT JOIN ngs_job ON ngs_job.task_id = task.task_id
			LEFT JOIN task_status ON ngs_job.status_id = task_status.status_id
			WHERE project_id = ?
			GROUP BY task_status.name, task.name
			ORDER BY task_name
	});

sub get_jobs_status {
	my ($class, $pid) = @_;

	my %job_status = ();

	my $sth = $class->sql_jobs_status;
	$sth->execute($pid);
	while (my $r = $sth->fetchrow_hashref) {
		$job_status{$r->{task_name}}->{$r->{status_name}} = $r->{num};
	}
	$sth->finish;

	wantarray ? %job_status : \%job_status;
}


1;
