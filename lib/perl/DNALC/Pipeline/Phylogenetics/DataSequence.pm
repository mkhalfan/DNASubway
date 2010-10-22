package DNALC::Pipeline::Phylogenetics::DataSequence;

#use DNALC::Pipeline::Config ();

use base qw(DNALC::Pipeline::DBI);

use DNALC::Pipeline::MasterProject ();
#use Data::Dumper;

__PACKAGE__->table('phy_data_sequence');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id source_id file_id display_id/);
__PACKAGE__->columns(Other => qw/seq created/);
__PACKAGE__->sequence('phy_data_sequence_id_seq');

__PACKAGE__->has_a(project_id => 'DNALC::Pipeline::Phylogenetics::Project');

__PACKAGE__->add_trigger(before_create => sub {
	$_[0]->{created} ||= POSIX::strftime "%Y-%m-%d %H:%M:%S", localtime(+time);
});

__PACKAGE__->set_sql(non_paired_sequences =>q {
	SELECT id 
	FROM phy_data_sequence AS ds
	LEFT JOIN phy_pair_sequence ps ON ds.id = ps.seq_id
	WHERE ds.project_id = ? AND ps.pair_id IS NULL
});



1;
