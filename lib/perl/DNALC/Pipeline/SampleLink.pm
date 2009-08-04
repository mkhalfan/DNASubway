package DNALC::Pipeline::SampleLink;

use strict;
use warnings;

use POSIX ();
use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('sample_link');
__PACKAGE__->columns(Primary => qw/link_id/);
__PACKAGE__->columns(Essential => qw/sample_id link_name link_url/);

__PACKAGE__->sequence('sample_link_link_id_seq');

__PACKAGE__->has_a(sample_id => 'DNALC::Pipeline::Sample');



1;
