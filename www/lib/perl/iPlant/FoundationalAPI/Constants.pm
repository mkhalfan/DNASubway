package iPlant::FoundationalAPI::Constants;

use strict;

use Exporter;
use vars qw(
		@ISA @EXPORT_OK %EXPORT_TAGS
	);
@ISA = qw(Exporter);
@EXPORT_OK = qw(
		kTrue kFalse
		kExitJobError kExitError kExitOK
	);
%EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

#------------------------------------------------------------------------------

sub kFalse {undef}
sub kTrue  {!kFalse}

sub kExitOK {0}
sub kExitError { -1}
sub kExitJobError {1}

1;
