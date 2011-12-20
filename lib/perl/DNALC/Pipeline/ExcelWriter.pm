package DNALC::Pipeline::ExcelWriter;

use strict;
use Spreadsheet::WriteExcel ();
use Data::Dumper;

{
	my $cf = {};

	sub new {
		my ($class, $args) = @_;
		#check the $args
		#
		my $self = {WS => Spreadsheet::WriteExcel->new($args->{file})};

		bless $self, __PACKAGE__;
	}


	sub new_ws{
		my ($self) = @_;
		$self->{WS}->add_worksheet;
	}

	sub set_header {
		my ($self, $header, $wsn, $row) = @_;

		$wsn ||= 0;
		my $h = $self->{WS}->add_format();
		$h->set_bold();
		$h->set_size(10);
		
		my $ws = $self->{WS}->sheets($wsn);
		
		# This inserts a blank row as the very first row, needed for BOLD
		#$ws -> write(0, 0, '');

		my $i = 0;
		foreach (@$header) {
			$ws->write($row, $i++, $_, $h);
		}
	}

	sub add_data {
		my ($self, $data, $wsn, $row) = @_;

		$wsn ||= 0;
		my $ws = $self->{WS}->sheets($wsn);
		#print STDERR Dumper( $data), $/;

		my $j = 0;
		foreach my $r (@$data) {
			$ws->write($row, $j, $r);
			$j++;
		}
	}

	sub close {
		my ($self) = @_;

		$self->{WS}->close;
	}

	sub DESTROY {
		my $self = shift;
		#warn "DESTROYING $self";
		$self->close if $self;
	}
}

1;
