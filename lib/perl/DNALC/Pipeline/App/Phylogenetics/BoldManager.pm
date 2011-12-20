package DNALC::Pipeline::App::Phylogenetics::BoldManager;

use common::sense;

use JSON::XS ();
use IO::File ();
use POSIX ();
use File::Path qw(mkpath);
use File::Spec ();
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use MIME::Lite ();
use URI::Escape;
use HTTP::Tiny ();
use XML::Simple;
use File::Basename;


use DNALC::Pipeline::Phylogenetics::Bold ();
use DNALC::Pipeline::Phylogenetics::BoldSeq ();
use DNALC::Pipeline::Phylogenetics::Pair ();
use DNALC::Pipeline::Phylogenetics::PairSequence ();
use DNALC::Pipeline::Phylogenetics::DataSequence ();
use DNALC::Pipeline::App::Phylogenetics::ProjectManager ();
use DNALC::Pipeline::Phylogenetics::DataFile ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::ExcelWriter ();
use Data::Dumper;

{
	sub new {
		my ($class, %args) = @_;
		my $cf = DNALC::Pipeline::Config->new;
		my $phy_conf = $cf->cf('PHYLOGENETICS');
		my $date =  POSIX::strftime "%Y-%m-%d", localtime(+time);
		my $dir_name = $date . '-' . random_string(7, 7);
		my $work_dir = $phy_conf->{BOLD_SUBMISSION_DIR} . '/' . $dir_name;
		if (!-d $work_dir) {
			mkpath($work_dir);
		}
		return bless {
			 work_dir => $work_dir,
			 dir_name => $dir_name,
			 zip_file_name => 'sequences.zip',
			 spreadsheet_name => 'spreadsheet.xls'
		}, __PACKAGE__;

	}
	
	# ----------------------------------------
	# Searches for and returns bold rows from
	# within our database where status is
	# pending
	#
	sub search {
		my ($self, $container) = @_;
		DNALC::Pipeline::Phylogenetics::Bold->search(status => 'pending', container => $container);
	}
	
	# ----------------------------------------
	# Create spreadsheet/worksheets for 
	# specimen data
	#
	sub create_spreadsheet {
		my ($self, @specimens) = @_;
		my $file = $self->{work_dir} . '/' . $self->{spreadsheet_name};
		my $xls  = DNALC::Pipeline::ExcelWriter->new({file => $file});
		die "Problems creating new excel file: $!" unless defined $xls;
		
		my @blank_header = (
			[''],
			[''],
			[''],
			['']
		);
		my @headers = (
			['Sample ID', 'Field ID', 'Museum Voucher ID', 'Collection Code', 'Institution Storing'],
			['Sample ID', 'Phylum', 'Class', 'Order', 'Family', 'Subfamily', 'Genus', 'Species', 'Identifier', 'Identifier Email', 'Identifier Institution'],
			['Sample ID', 'Sex', 'Reproduction', 'Life Stage', 'Extra Info', 'Notes'],
			['Sample ID', 'Collectors', 'Collection Date', 'Continent/Ocean', 'Country', 'State/Province', 'Region', 'Sector', 'Exact Site', 'Latitude', 'Longitude', 'Elevate']
		);
	
		# Creates 4 worksheets with headers 
		for (0 .. 3){
			$xls->new_ws;
			$xls->set_header($blank_header[$_], $_, 0); #adds blank header row required for this template
			$xls->set_header($headers[$_], $_, 1);
		}
		
		my $row = 2;
		foreach (@specimens){
			my $sample_id = $_->specimen_id;
			my $data = $self->parse_json($_->data);

			my @data_array = (
				[$sample_id, $sample_id, '', '', $data->{institution_storing}],
				[$sample_id, $data->{phylum}, $data->{class}, $data->{order}, $data->{family}, '', $data->{genus}, $data->{genus} . ' ' . $data->{species}, $data->{tax}, $data->{tax_email}, ''],
				[$sample_id, $data->{sex}, '', $data->{stage}, '', $data->{notes}],
				[$sample_id, $data->{collectors}, $data->{date_collected},'', $data->{country}, $data->{state},'','', $data->{site_desc}, $data->{latitude}, $data->{longitude}, ''],
			);

			for (0 .. 3){
				$xls->add_data($data_array[$_], $_, $row);
			}		
			$row++
		}

		$xls->close;
	}

	# -----------------------------------------
	# Parse JSON data  
	#
	sub parse_json {
		my ($self, $json_data) = @_;
		my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
		my $data = $coder->decode($json_data);
		#return $data->{site_desc};
		return $data;
	}

	# ----------------------------------------
	# Create FASTA files and zip them
	#
	sub create_fasta {
		my ($self, @specimens) = @_;
		my $zip = Archive::Zip->new();
		foreach (@specimens){
			my $sample_id = $_->specimen_id;
			my $seq = DNALC::Pipeline::Phylogenetics::Pair->retrieve($_->sequence_id)->consensus;
			my $fasta = $self->{work_dir} . '/' . $sample_id . '.fasta';
			my $outfile = IO::File->new;
			if ($outfile->open($fasta, "w")){
				print $outfile ">", $sample_id, "|\n";
				print $outfile $seq;
				undef $outfile;
				print "wrote to file: ", $fasta, "\n";
				$zip->addFile($fasta, "$sample_id.fasta");
			}
			else {
				print "failed to write fasta file: ", $!, "\n";
			}
		}
		unless ($zip->writeToFileNamed($self->{work_dir} . '/' . $self->{zip_file_name}) == AZ_OK){
			die $!, "\n";
		}
	}

	# ----------------------------------------
	# Email spreadsheet and zipped fasta files
	#
	sub email {
		my ($self, $container) = @_;
		my $cf = DNALC::Pipeline::Config->new->cf('PIPELINE');
		my $no_error = 1;
		my $msg = MIME::Lite->new (
			From => '"DNASubway Admin" <dnalcadmin@cshl.edu>',
			To => 'mkhalfan@cshl.edu',
			Subject => "DNASubway - $container",
			Type => 'multipart/mixed',
		);
		$msg->attach (
			Type => 'text/plain',
			Data => "DNASubway - $container",
		);
		my $zipfile = File::Spec->catfile($self->{work_dir}, $self->{zip_file_name});
		if ( -f $zipfile) {
			$msg->attach (
				Type => 'application/zip',
				Path => $zipfile,
				Filename => $self->{zip_file_name},
				Disposition => 'attachment'
			) or die "Error adding zip attachment: $!\n";
		}
		else {
			print "File $self->{zip_file_name} not found. \n";
			$no_error = 0;
		}
		my $spreadsheet = File::Spec->catfile($self->{work_dir}, $self->{spreadsheet_name});
		if (-f $spreadsheet) {
			 $msg->attach (
				Type => 'application/vnd.ms-excel',
				Path => $spreadsheet,
				Filename => $self->{spreadsheet_name},
				Disposition => 'attachment'
			) or die "Error attaching spreadsheet: $!\n";
		}
		else {
			print "File $self->{spreadsheet_name} not found. \n";
			$no_error = 0;
		}

		my $sent;

		if ($no_error) {
			#print STDERR Dumper( $msg ), $/;
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
	# where the files can be found
	#
	sub change_status{
		my ($self, @specimens) = @_;
		for (@specimens) {
			$_->status($self->{dir_name});
			if ($_->update){
				print "Bold Entry ", $_->id, " updated. \n";
			}
		}
	}

	# ----------------------------------------
	# Do an eSearch on Bold for an array 
	# of sample ids. Return an array of 
	# hashes, key is sample id, value is
	# process id, for sample id's where 
	# records exist.
	#
	sub eSearch{
		my ($self, @sampleids) = @_;
		my %idhash;
		my $ht = HTTP::Tiny->new(timeout => 30);
		foreach (@sampleids){
			my $cleansampleid = uri_escape($_);
			my $response = $ht->get('http://services.boldsystems.org/eSearch.php?id_type=sampleid&ids=(' . $cleansampleid .')');
			if ($response->{success} && length $response->{content}){
				my $data = $response->{content};
				my $xml = XMLin($data);
				if ($xml->{record}) {
					$idhash {$_} = $xml->{record}->{processid};
					my $dbr  = DNALC::Pipeline::Phylogenetics::Bold->search(specimen_id => $_)->next;
					# Update DB with Process ID 
					$dbr->process_id($xml->{record}->{processid});
					$dbr->update;
					print "process id for sample id $_ is: $xml->{record}->{processid} \n";
				}
				else {
					print "no record exists for id: $_ \n";
				}
			}
		}
		return \%idhash;
	}

	# ----------------------------------------
	# Create spreadsheet of trace file data
	#
	sub create_spreadsheet2 {
		my ($self, $idhash) = @_;
		#my $file = $self->{work_dir} . '/' . 'tracedata.xls';
		my $file = '/home/mkhalfan/tracedata.xls';
		my $xls  = DNALC::Pipeline::ExcelWriter->new({file => $file});
	    die "Problems creating new excel file: $!" unless defined $xls;

		my $zip = Archive::Zip->new();	

		my $boldseq;
		my $pair_id;
		my $forward;
		my $reverse;
		my $f_file_path;
		my $r_file_path;
		my $f_file_name;
		my $r_file_name;

		my @headers = (
			['Filename (.ab1)', 'Score File (.phd.1)', 'FORWARD PCR PRIMER', 'REVERSE PCR PRIMER', 'SEQUENCING PRIMER', 'Read Direction', 'Process ID', '', '', 'Marker']
		);

		$xls->new_ws;
		$xls->set_header($headers[$_], $_, 0);

		my $row = 1;
		foreach my $sampleid (keys %$idhash){
			my ($bold) = DNALC::Pipeline::Phylogenetics::Bold->search(specimen_id => $sampleid);
			if ($bold){
				($boldseq) = DNALC::Pipeline::Phylogenetics::BoldSeq->search(bold_id => $bold->id);
			}
			if ($boldseq) {
				$pair_id = $boldseq->pair_id;
			}
			if ($pair_id) {
				my ($forward_ps) = DNALC::Pipeline::Phylogenetics::PairSequence->search(pair_id => $pair_id, strand=> "F");
				my ($reverse_ps) = DNALC::Pipeline::Phylogenetics::PairSequence->search(pair_id => $pair_id, strand=> "R");
				$forward = $forward_ps->seq if $forward_ps;
				$reverse = $reverse_ps->seq if $reverse_ps;
			}
			if ($forward && $reverse) {
				my $f_file = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($forward->file_id);
				my $r_file = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($reverse->file_id);
				$f_file_path = $f_file->file_path if $f_file;
				$r_file_path = $r_file->file_path if $r_file;
				$f_file_name = basename $f_file_path;
				$r_file_name = basename $r_file_path;
				$zip->addFile($f_file_path, $f_file_name);
				$zip->addFile($r_file_path, $r_file_name);
			}
			
			my @data_array = (
				[$f_file_name, '', '', '', '', 'Forward', $idhash->{$sampleid}, '', '', 'Marker'],
				[$r_file_name, '', '', '', '', 'Reverse', $idhash->{$sampleid}, '', '', 'Marker']
			);

			foreach (0 .. 1) {
				$xls->add_data($data_array[$_], 0, $row);
				$row++;
			}
			$row++;
		}
		$xls->close;
		unless ($zip->writeToFileNamed('/home/mkhalfan/trace_files.zip') == AZ_OK) {
			die $!, "\n";
		}
	}

	
}

1;

#__END__
package main;
sub main {
	my $bm = DNALC::Pipeline::App::Phylogenetics::BoldManager->new;
	if (0) {
		my @specimens= $bm->search();
		if (@specimens){
			$bm->create_spreadsheet(@specimens);
			$bm->create_fasta(@specimens);
			if ($bm->email) {
				$bm->change_status(@specimens);
			}
		}
	}
	my $h =  $bm->eSearch(('01-SRNP-18806'));
	$bm->create_spreadsheet2($h);
}
main();
