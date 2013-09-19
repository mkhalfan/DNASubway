package DNALC::Pipeline::TargetSample;

use Carp;
use POSIX ();
use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('target_sample');
__PACKAGE__->columns(Primary => qw/sample_id/);
__PACKAGE__->columns(Essential => qw/name organism common_name type
							class_name function_name source_name source_url 
		/);
__PACKAGE__->columns(Other => qw/active created updated/);

__PACKAGE__->sequence('target_sample_sample_id_seq');

__PACKAGE__->add_trigger(before_create => sub {
    $_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
    $_[0]->{updated} ||= $_[0]->{created};
});

__PACKAGE__->add_trigger(before_update => sub {
    $_[0]->{updated} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});



sub new {
	my ($class, $sample_id) = @_;
	#TODO: check if the file exists, else create it using the data in DB
	#print STDERR  "@_", $/;
	$class->retrieve($sample_id);
}


__PACKAGE__->set_sql('update_sequence', q{
	UPDATE __TABLE__
	SET sequence_data = ?
	WHERE sample_id = ?
});
__PACKAGE__->set_sql('get_sequence', q{
	SELECT sequence_data 
	FROM __TABLE__
	WHERE sample_id = ?
});

sub sequence_data {
	my ($self, $data) = @_;

	my $sth;
	if (defined $data) {
		$sth = $self->sql_update_sequence;
		$sth->execute($data, $self->id);
	}
	else {
		my $sth = $self->sql_get_sequence;
		$sth->execute($self->id);

		($data) = $sth->fetchrow_array;
		$sth->finish;
	}
	return $data;
}

sub config {
	my $cf = DNALC::Pipeline::Config->new;
	return $cf->cf('SAMPLE');
}


sub sample_dir {
	my ($self) = @_;

	my $cf = $self->config;
	
	return $cf->{target_samples_dir} . '/' . $self->id;
}


#-------------------------------------------------------------

1;


