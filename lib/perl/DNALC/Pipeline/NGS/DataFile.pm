package DNALC::Pipeline::NGS::DataFile;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use Data::Dumper;

__PACKAGE__->table('ngs_data_file');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_name file_path file_type 
									is_input is_local qc_file_id trimmed_file_id created/);
__PACKAGE__->sequence('ngs_data_file_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');
__PACKAGE__->has_a(source_id => 'DNALC::Pipeline::NGS::DataSource');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->set_sql (count_QCd => q{
		SELECT CASE WHEN qc_file_id IS NULL THEN 0 ELSE 1 END AS qc_group, count(*) AS num
		FROM ngs_data_file 
		WHERE project_id = ?
		AND is_input = true
		GROUP BY qc_group
	});

__PACKAGE__->set_sql (qc_status => q{
		SELECT count(*) AS num, task_status.name 
		FROM ngs_job 
		LEFT JOIN task_status ON ngs_job.status_id = task_status.status_id
		WHERE project_id = ?
		AND task_id = (SELECT task_id FROM task WHERE name IN ('ngs_fastqc'))
		GROUP BY task_status.name
	});

sub get_qc_status {
	my ($class, $project_id) = @_;
	my %qced_or_not = ();
	my %qced_status = ();
	my $total = 0;

	my $sth = $class->sql_count_QCd;
	$sth->execute($project_id);
	while (my $r = $sth->fetchrow_hashref) {
		$qced_or_not{$r->{qc_group}} = $r->{num};
	}
	$sth->finish;

	# no input files => QC is disabled
	unless (keys %qced_or_not) {
		return {total => $total, status => 'disabled'};
	}

	$sth = $class->sql_qc_status;
	$sth->execute($project_id);
	while (my $r = $sth->fetchrow_hashref) {
		$qced_status{$r->{name}} = $r->{num};
		$total += $r->{num};
	}
	$sth->finish;

	#print STDERR Dumper( \%qced_or_not, \%qced_status), $/;

	my $status = 'not-processed';
	if (defined $qced_status{error}) {
		$status = 'error';
	}
	elsif (defined $qced_status{processing}) {
		$status = 'processing';
	}
	elsif (1 == keys %qced_or_not && defined $qced_status{done} && $qced_status{done} == $qced_or_not{1}) {
		$status = 'done';
	}

	return return {total => $total, status => $status};
}


sub project {
	$_[0]->project_id;
}

sub source {
	$_[0]->source_id;
}

sub trimmed_file {
	my $file = shift;
	return __PACKAGE__->retrieve($file->trimmed_file_id);
}

sub qc_report {
	my $file = shift;
	return unless $file->qc_file_id;
	
	my $qcf = DNALC::Pipeline::NGS::DataFile->retrieve($file->qc_file_id);
	return $qcf->file_path;
}


1;

