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

	sub do_transaction {
		my $class = shift;
		my ( $code ) = @_;
		# Turn off AutoCommit for this scope.
		# A commit will occur at the exit of this block automatically,
		# when the local AutoCommit goes out of scope.
		local $class->db_Main->{ AutoCommit };

		# Execute the required code inside the transaction.
		eval { $code->() };
		if ( $@ ) {
			my $commit_error = $@;
			eval { $class->dbi_rollback }; # might also die!
			die $commit_error;
		}
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
