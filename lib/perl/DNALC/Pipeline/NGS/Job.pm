package DNALC::Pipeline::NGS::Job;

use POSIX ();
use Data::Dumper;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('ngs_job');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/api_job_id project_id task_id user_id status_id deleted/);
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

1;
