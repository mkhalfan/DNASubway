package DNALC::Pipeline::SampleLink;

use strict;
use warnings;

use POSIX ();
use base qw(DNALC::Pipeline::DBI);
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw/random_string/;

__PACKAGE__->table('sample_link');
__PACKAGE__->columns(Primary => qw/link_id/);
__PACKAGE__->columns(Essential => qw/sample_id link_name link_url
				link_segment link_start link_stop link_type/);

__PACKAGE__->sequence('sample_link_link_id_seq');

__PACKAGE__->has_a(sample_id => 'DNALC::Pipeline::Sample');


sub remote_link {
	my ($self, $project_id) = @_;
	return unless ref $self eq __PACKAGE__;

	#$_->link_url . $remote_param . $eurl . $_->id. $remote_param_end
	my $pcf = DNALC::Pipeline::Config->new->cf('PIPELINE');
	my $cf  = DNALC::Pipeline::Config->new->cf('SAMPLE');

	my $host = $pcf->{PROJECT_HOME};
	my $local_link = $host =~ /-dev\.dnalc/
				? "http://green.cshl.edu/project/dnasubway_exporter"
				: $host . "/project/dnasubway_exporter";
	$local_link .= "/$project_id/$self/" . $self->link_type 
				. '/' . random_string() . '/dnasubway';

	my $params = $cf->{export_browsers}->{ $self->link_type };

	$self->link_url . $params->{param_prefix} . $local_link . $params->{param_postfix};
}

1;
