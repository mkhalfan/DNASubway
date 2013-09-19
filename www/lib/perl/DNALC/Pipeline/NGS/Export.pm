package DNALC::Pipeline::NGS::Export;

use base qw(DNALC::Pipeline::DBI);
use POSIX ();
use Data::Dumper;

__PACKAGE__->table('ngs_export');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/
		     user_id
		     project_id
		     file_id
		     is_public
		     description/);

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::NGS::Project');

__PACKAGE__->set_sql(get_user_export_files => q{
                SELECT ngs_export.file_id, ngs_data_file.file_name,ngs_data_file.file_path,ngs_export.description 
                FROM ngs_export,ngs_data_file
                WHERE ngs_export.user_id = ?
                AND ngs_export.file_id = ngs_data_file.file_id
});

__PACKAGE__->set_sql(get_public_export_files => q{
                SELECT ngs_export.file_id, ngs_data_file.file_name,ngs_data_file.file_path,ngs_export.description
                FROM ngs_export,ngs_data_file
		AND ngs_export.is_public = TRUE
                AND ngs_export.file_id = ngs_data_file.file_id
});

__PACKAGE__->set_sql(export_file => q{
                INSERT INTO ngs_export (user_id,project_id,file_id,is_public,description)
		VALUES (?,?,?,?,?)
});


sub get_export_files {
	my ($class, $user_id, $public) = @_;
	my $total = 0;
	
	my $sth;
	unless ($public) {
	    $sth = $class->get_user_export_files;
	    $sth->execute($user_id);
	}
	else {
	    $sth = $class->get_public_export_files;
	    $sth->execute;
	}

	while (my $r = $sth->fetchrow_hashref) {

	}
	$sth->finish;

	
}


__PACKAGE__->set_sql (local_output_files_of_parent_job => q{
		SELECT * FROM ngs_data_file 
		WHERE id IN (
			SELECT file_id from ngs_job_output_file
			WHERE job_id IN (
				SELECT job_id from ngs_job_output_file
					WHERE file_id IN (
						SELECT file_id FROM ngs_job_input_file
							WHERE job_id = ? AND project_id = ?
						)
				)
		)
		AND is_local = true
	});

sub get_local_output_files_of_parent_job {
	my ($class, $job_id, $project_id) = @_;

	return $class->search_local_output_files_of_parent_job($job_id, $project_id);
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

