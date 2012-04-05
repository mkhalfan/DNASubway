package DNALC::Pipeline::Phylogenetics::Bold;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('phy_bold');
__PACKAGE__->columns(Primary => qw/id/);
__PACKAGE__->columns(Essential => qw/project_id sequence_id specimen_id status container/);
__PACKAGE__->columns(Other => qw/data created updated/);

__PACKAGE__->has_many(bold_sequences => 'DNALC::Pipeline::Phylogenetics::BoldSeq');
__PACKAGE__->has_many(photos => 'DNALC::Pipeline::Phylogenetics::BoldPhoto');

__PACKAGE__->add_trigger('before_create' => sub {
			my $self = shift;
			$self->{id} = $self->_get_next_id;
			$self->{specimen_id} = sprintf("DNAS-%X-%d", $self->{id}, $self->{sequence_id} + int(rand(200)));
});

__PACKAGE__->set_sql(next_id => q{select nextval('phy_bold_id_seq')});

sub _get_next_id {
	my $class = shift;
	$class->sql_next_id->select_val;
}

1;
