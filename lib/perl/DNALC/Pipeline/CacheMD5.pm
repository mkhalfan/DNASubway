package DNALC::Pipeline::CacheMD5;
#===============================================================================
#
#         FILE:  CacheMD5.pm
#
#  DESCRIPTION: Stores/Retrieves project/routines cache
#        NOTES:  ---
#       AUTHOR:  Cornel Ghiban, ghiban@cshl.edu
#      COMPANY:  DNALC, Cold Spring Harbor Laboratory
#      VERSION:  1.0
#      CREATED:  05/18/09 14:44:37
#     REVISION:  $Id
#===============================================================================

use strict;
use warnings;

use base qw(DNALC::Pipeline::DBI);

__PACKAGE__->table('cachemd5');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(Essential => qw/project_id task_name crc/);

__PACKAGE__->sequence('cachemd5_id_seq');

1;
