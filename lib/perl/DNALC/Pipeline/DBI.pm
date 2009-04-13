package DNALC::Pipeline::DBI;

use strict;
use DNALC::Pipeline::Config ();
use base qw/Class::DBI::Pg/;

{ 

	my $config = DNALC::Pipeline::Config->new;
	__PACKAGE__->connection( @{ $config->cf('DB') } );

	sub getDBH {
		return __PACKAGE__->db_Main;
	}

#-------------------------------------------------------------------------- 
# 	sub connect {
# 		my $class = shift;
# 
# 		unless ($Dbh && $Dbh->{Active} &&  $Dbh->ping) {
# 			my $config = DNALC::Pipeline::Config->new;
# 			$Dbh = DBI->connect_cached( @{ $config->cf('DB') }) || confess $DBI::errstr;
# 		}
# 
# 		return $Dbh;
# 	}
}

1;
