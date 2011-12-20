package DNALC::Pipeline::App::Phylogenetics::GBManager;

use common::sense;

use JSON::XS ();
use IO::File ();
use POSIX ();
use File::Path qw(mkpath);
use File::Spec ();
use MIME::Lite ();
use URI::Escape;
use HTTP::Tiny ();
use XML::Simple;
use File::Basename;

use DNALC::Pipeline::Phylogenetics::Bold ();
use DNALC::Pipeline::Phylogenetics::Pair ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);


{
	sub new {
		my ($class, %args) = @_;
		my $cf = DNALC::Pipeline::Config->new;
		my $phy_conf = $cf->cf('PHYLOGENETICS');
		#my $date =  POSIX::strftime "%Y-%m-%d", localtime(+time);
		#my $dir_name = $date . '-' . random_string(7, 7);
		#my $work_dir = $phy_conf->{GB_SUBMISSION_DIR} . '/' . $dir_name;
		my $work_dir = $phy_conf->{GB_SUBMISSION_DIR};
		if (!-d $work_dir) {
			mkpath($work_dir);
		}
		my $tbl2asn_template = $phy_conf->{GB_TBL2ASN_TEMPLATE_PATH};
		
		return bless {
			work_dir => $work_dir,
			tbl2asn_template => $tbl2asn_template,
			#dir_name => $dir_name,
			#zip_file_name => 'sequences.zip',
			#spreadsheet_name => 'spreadsheet.xls'
		}, __PACKAGE__;
	}

	# ---------------------------------------
	# Searches for and returns bold rows from 
	# within the DB where status == 'pending'
	#
	sub search {
		my ($self, $container) = @_;
		DNALC::Pipeline::Phylogenetics::Bold->search(status => 'pending', container => $container);
	}

	# ---------------------------------------
	# Create directory for each submission here
	#
	sub create_dir{
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";
		if (!-d $work_dir) {
			mkpath($work_dir);
			print "Made dir: $work_dir \n";
		}

	}

	# -----------------------------------------
	# Parse JSON data from DB (metadata)
	#
	sub _parse_json {
		my ($self, $json_data) = @_;
		my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
		my $data = $coder->decode($json_data);
		return $data;
	}
	
	# ---------------------------------------
	# Get sequences and create FASTA files
	# 
	sub create_fasta {
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $id = $record->specimen_id;

		# Get the organism name, need it for the FASTA file header
		my $data = $self->_parse_json($record->data);
		my $organism = $data->{genus} . ' ' . $data->{species};

		# Get the sequence, then remove any dahses which may exist
		my $seq = DNALC::Pipeline::Phylogenetics::Pair->retrieve($record->sequence_id)->consensus;
		$seq =~ s/-//g;

		# Create the FASTA file
		my $fasta_file = $self->{work_dir} . "/$seq_id/$id.fsa";
		my $outfile = IO::File->new;
		if ($outfile->open($fasta_file, "w")){
			print $outfile ">", $id, " [organism=$organism]", "\n";
			print $outfile $seq;
			undef $outfile;
		}
		else {
			print "FAILED to open fasta file: ", $!, "\n";
		}
	}

	# ---------------------------------------
	# Creates the Source Modifer Tables
	# (all the metadata)
	#
	sub create_smt {
		my ($self, $record) = @_;
		my $id = $record->specimen_id;
		my $seq_id = $record->sequence_id;

		# Create column headers which is needed for the SMT file
		my @column_headers_array = ("Sequence_ID",  "Specimen_voucer", 
			"Identified_by", "Collected_by", "Collection_date", "Country", 
			"Lat_Lon", "Note", "Sex", "Dev_stage");
		my $column_headers = join("\t", @column_headers_array);

		# Get the JSON data from the DB and parse it in order to populate the SMT
		my $data = $self->_parse_json($record->data);
		my @column_data_array = ($id, "Specimen Voucher", 
			"identified by", $data->{collectors}, $data->{date_collected}, $data->{country},
			"lat + lon", $data->{notes}, $data->{sex}, $data->{stage});
		my $column_data = join("\t", @column_data_array);

		# Create and populate the SMT file
		my $smt_file = $self->{work_dir} . "/$seq_id/$id.src";
		my $outfile = IO::File->new;
		if ($outfile->open($smt_file, "w")){
			print $outfile $column_headers, "\n";
			print $outfile $column_data;	
		}
		else {
			print "FAILED to create smt file: ", $!, "\n";
		}
	}
	
	# ---------------------------------------
	# Run tbl2asn
	#
	sub run_tbl2asn {
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";

		## 
		## TODO: Update path to run command tbl2asn
		##
		my $status = system("/home/mkhalfan/tbl2asn/linux.tbl2asn", "-t", $self->{tbl2asn_template}, "-p", $work_dir);
		if (($status >>=8) != 0) {
			die "FAILED: tbl2asn";
		}
	}

	# ---------------------------------------
	# Email the .sqn file
	# Returns TRUE upon email success
	#
	sub email {
		my ($self, $record) = @_;
		my $id = $record->specimen_id;
		my $seq_id = $record->sequence_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";

		my $cf = DNALC::Pipeline::Config->new->cf('PIPELINE');
		my $no_error = 1;


		my $msg = MIME::Lite->new (
			From => '"DNASubway Admin" <dnalcadmin@cshl.edu>',
			To => 'mkhalfan@cshl.edu, ghiban@cshl.edu',
			Subject => "Submission from DNASubway",
			Type => 'multipart/mixed',
		);
		$msg->attach (
			Type => 'text/plain',
			Data => '.sqn file attached',
		);
		if (-f "$work_dir/$id.sqn"){
			$msg->attach (
				Type => 'application/sqn',
				Path => "$work_dir/$id.sqn",
				Filename => "$id.sqn",
				Disposition => 'attachment',
			) or die "ERROR adding .sqn attachment: $!\n";
		}
		else {
			print "File: $work_dir/$id.sqn not found. \n";
			$no_error = 0;
		}
		
		my $sent;
		if ($no_error) {
			eval {
				if (defined $cf->{SMTP_SERVER} && $cf->{SMTP_SERVER} ne "") {
					$sent = $msg->send("smtp", $cf->{SMTP_SERVER}, Timeout=>30);
				}
				else {
					$sent = $msg->send;
				}
			};
			if ($@) {
				print STDERR "Error: " . $@ . "\n";
				$sent = $msg->send;
			}
		}
		return $sent;
	}

	# ----------------------------------------
	# Change status from Pending to dir_name
	# where submission files are located
	#
	sub change_status{
		my ($self, $record) = @_;
		$record->status($record->sequence_id);
		if ($record->update){
			print "GB Entry ", $_->id, " updated. \n";
		}
	}

}

1;

#__END__
package main;
sub main {
	my $gbm = DNALC::Pipeline::App::Phylogenetics::GBManager->new;
	my @pending_submissions = $gbm->search('DNAS');
	foreach (@pending_submissions){
		print $_, $/;
		$gbm->create_dir($_);
		$gbm->create_fasta($_);
		$gbm->create_smt($_);
		$gbm->run_tbl2asn($_);
		if ($gbm->email($_)) {
			$gbm->change_status($_);
		}
	}
}
main();
