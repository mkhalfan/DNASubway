package DNALC::Pipeline::App::Phylogenetics::GBManager;

use strict;

use JSON::XS ();
use IO::File ();
use POSIX ();
use File::Path qw(mkpath);
use File::Spec ();
use HTTP::Tiny ();
use XML::Simple;
use File::Basename;
use Archive::Tar;
use Cwd;
use Net::FTP ();
use MIME::Lite ();
use Bio::Trace::ABIF ();

use DNALC::Pipeline::App::Phylogenetics::ProjectManager();
use DNALC::Pipeline::Phylogenetics::Bold ();
use DNALC::Pipeline::Phylogenetics::BoldSeq ();
use DNALC::Pipeline::Phylogenetics::PairSequence ();
use DNALC::Pipeline::Phylogenetics::Pair ();
use DNALC::Pipeline::Phylogenetics::DataFile ();
use DNALC::Pipeline::Phylogenetics::Project();
use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::App::Utils ();
use DNALC::Pipeline::Barcode::Annotation;


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
		my $ftp_user = $phy_conf->{GB_FTP_USER};
		my $ftp_pw = $phy_conf->{GB_FTP_PW};
		my $validation_user = $phy_conf->{GB_VALIDATION_USER};
		my $pwd = getcwd;
		
		return bless {
			work_dir => $work_dir,
			tbl2asn_template => $tbl2asn_template,
			pwd => $pwd,
			ftp_user => $ftp_user,
			ftp_pw => $ftp_pw,
			ftp_passive => $phy_conf->{GB_FTP_PASSIVE} || 0,
			validation_user => $validation_user,
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
			print STDERR "Made dir: $work_dir \n";
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

		# Get the translation table to be used
		my $trans_table = $data->{trans_table};

		# Get the Project type (ex: UBP, BLI), need it for the FASTA file header (bioproject ID)
		my $bioproject_name = $data->{project};
		my $bioproject_list = DNALC::Pipeline::Config->new->cf('BARCODING_PROJECTS');
		my $bioproject_id = $bioproject_list->{$bioproject_name}; 

		# Get the sequence, then remove any dahses which may exist
		my $seq = DNALC::Pipeline::Phylogenetics::Pair->retrieve($record->sequence_id)->consensus;
		$seq =~ s/-//g;

		# Create the FASTA file
		my $fasta_file = $self->{work_dir} . "/$seq_id/$id.fsa";
		my $outfile = IO::File->new;
		if ($outfile->open($fasta_file, "w")){
			print $outfile ">", $id, " [BioProject=$bioproject_id] [tech=barcode] [organism=$organism]";
			print $outfile " [mgcode=$trans_table] [location=mitochondrion]" if ($trans_table != 1);
			print $outfile "\n";
			print $outfile $seq;
			undef $outfile;
			print STDERR "Fasta file created: ", $self->{work_dir}, "/$seq_id/$id.fsa\n";
			return {status => 'success'};
		}
		else {
			print STDERR "FAILED to create fasta file: ", $!, "\n";
			$self->_email_admin($record, "FAILED to create fasta file: $!");
			return {status => 'error', 'message' => "FAILED to create fasta file: $!" }
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
		my @column_headers_array = ("Sequence_ID",  "Isolate", "Isolation_source", 
			"Identified_by", "Collected_by", "Collection_date", "Country", 
			"Lat_Lon", "Note", "Sex", "Dev_stage", "Fwd_primer_name", 
			"Fwd_primer_seq", "Rev_primer_name", "Rev_primer_seq");
		my $column_headers = join("\t", @column_headers_array);

		# Get the JSON data from the DB and parse it in order to populate the SMT
		my $data = $self->_parse_json($record->data);
		my %data_hash = %$data;
		my $names = {};

		# Create a hashref of hashrefs which contain author names
        # Ex: %$data_hash->{1}->{first} = "Mohammed"
        # {1} indicates author number (1 is always present, after 1
        # these numbers are not sequential or continuous, but they
        # are unique. Ex: 1, 5, 3). {first} indicates first name.
        # Keys here are either {first} or {last}
        for (keys %data_hash) {
            if ($_ =~ /author_(first|last)(\d+)$/) {
                $names->{$2}->{$1} = $data_hash{$_};
            }
        }

		# create the names entry for populating the SMT
        # using the information collected above in %data_hash
        my $names_new = "";
        for my $person_id (sort keys %$names){
            my $first = $names->{$person_id}->{first};
            my $last = $names->{$person_id}->{"last"};
            $names_new = $names_new . "$first $last, ";
        }

		# Get the primer sequences corresponding to the primer names
		#my $f_primer_name = $data->{f_primer};
		#my $r_primer_name = $data->{r_primer};
		#my $f_primer_seq = $self->_get_primer_sequence('forward', $f_primer_name);
		#my $r_primer_seq = $self->_get_primer_sequence('reverse', $r_primer_name);

		my $f_primer_name = $self->_get_primer_sequence('forward', $data->{f_primer})->{'name'};
		my $r_primer_name = $self->_get_primer_sequence('reverse', $data->{f_primer})->{'name'};
		my $f_primer_seq = $self->_get_primer_sequence('forward', $data->{f_primer})->{'seq'};
		my $r_primer_seq = $self->_get_primer_sequence('reverse', $data->{f_primer})->{'seq'};


		# Convert the date to the correct format
		my %months = (
			'01' => 'Jan',
			'02' => 'Feb',
			'03' => 'Mar',
			'04' => 'Apr',
			'05' => 'May',
			'06' => 'Jun',
			'07' => 'Jul',
			'08' => 'Aug',
			'09' => 'Sep',
			'10' => 'Oct',
			'11' => 'Nov',
			'12' => 'Dec',
		);
		my ($d, $m, $y) = split '/', $data->{date_collected};
		my $date_collected = "$d-$months{$m}-$y";

		# Populate the SMT file with the data gathered above
		my @column_data_array = ($id, $id, $data->{isolation_source}, $data->{tax}, $names_new, 
			$date_collected, "$data->{country}: " .  $data->{state} . ", $data->{city}, $data->{site_desc}", 
			$data->{latitude} . " " . $data->{longitude}, 
			$data->{notes}, $data->{sex}, $data->{stage}, $f_primer_name,
			$f_primer_seq, $r_primer_name, $r_primer_seq);
		my $column_data = join("\t", @column_data_array);

		# Create and populate the SMT file
		my $smt_file = $self->{work_dir} . "/$seq_id/$id.src";
		my $outfile = IO::File->new;
		if ($outfile->open($smt_file, "w")){
			print $outfile $column_headers, "\n";
			print $outfile $column_data;
			undef $outfile;
			print STDERR "SMT file craeted: " . $self->{work_dir} . "/$seq_id/$id.src\n";
			return {status => 'success'};
		}
		else {
			print STDERR "FAILED to create smt file: ", $!, "\n";
			$self->_email_admin($record, "FAILED to create smt file: $!");
			return {status => 'error', 'message' =>  "FAILED to create smt file: $!" };
		}
	}

	# ---------------------------------------
	# Get the primer sequence corresponding
	# to the primer id
	#
	sub _get_primer_sequence {
		my ($self, $strand, $primer_id) = @_;
		my $primers = DNALC::Pipeline::Config->new->cf('PRIMERS');

		#my ($primer_seq) = 
		#		map { $_->{$primer_id}}
		#   	grep { grep {/^$primer_id$/} keys %$_;}
		#   	map { my ($k, $v) = each %$_; $v;} 
		#	@{$primers->{$strand}};

		#return $primer_seq;

		my $name = $primers->{$strand}->{$primer_id}->{'name'};
		my $seq  = $primers->{$strand}->{$primer_id}->{'seq'};

		return {name => $name, seq => $seq};

	}

	# ---------------------------------------
	# Make the template file
	#
	sub make_template {
		my ($self, $record) = @_;
		my $data = $self->_parse_json($record->data);
		my $seq_id = $record->sequence_id;
		my %data_hash = %$data;
		my $names = {};
	
		# Create a hashref of hashrefs which contain author names
		# Ex: %$data_hash->{1}->{first} = "Mohammed"
		# {1} indicates author number (1 is always present, after 1
		# these numbers are not sequential or continuous, but they 
		# are unique. Ex: 1, 5, 3). {first} indicates first name. 
		# Keys here are either {first} or {last}
		for (keys %data_hash) {
			if ($_ =~ /author_(first|last)(\d+)$/) {
				$names->{$2}->{$1} = $data_hash{$_};
			}
		}
		
		# create the names entry in the syntax required by the 
		# template.sbt file using the information collected 
		# above in %data_hash
		my $names_new = "";
		for my $person_id (sort keys %$names){
			my $first = $names->{$person_id}->{first};
			my $last = $names->{$person_id}->{"last"};
			my $initial = uc(substr($first, 0, 1)) . ".";
			$names_new = $names_new . "{name name {last \"$last\", first \"$first\", initials \"$initial\", suffix \"\"}},";
		}
		
		# Using the master template, create the new template with the new author names
		# Step 1: Open the master template, write it to the string $sbt
		my $template = $self->{tbl2asn_template};
		my $file = IO::File->new;
		my $sbt;
		if($file->open($template, 'r')){
			my @lines;
			@lines = <$file>;
			$sbt = join("", @lines);
			undef $file;
		}
		# Step 2: replace the string __$NAMES__ in the master template with $names_new created above
		$sbt =~ s/__\$NAMES__/$names_new/g;

		# Step 3: create a new template.sbt file in this submission directory
		my $mod_template = $self->{work_dir} . "/$seq_id/template.sbt";
		my $file2 = IO::File->new;
		if ($file2->open($mod_template, "w")){
			print $file2 $sbt;
			undef $file2;
			print STDERR "template.sbt file craeted: " . $self->{work_dir} . "/$seq_id/template.sbt\n";
			return {status => 'success'};
		}
		else {
			print STDERR "FAILED to create sbt template file: ", $!, "\n";
			$self->_email_admin($record, "FAILED to create sbt template file: $!");
			return {status => 'error', 'message' => "FAILED to create sbt template file: $!" };
		}
	}
	
	# ---------------------------------------
	# Create the Feature Table (annotations)
	#
	sub create_feature_table {
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $id = $record->specimen_id;
		my $pid = $record->project_id;

		my $pm = DNALC::Pipeline::App::Phylogenetics::ProjectManager->new($pid);
		my $project_type = $pm->project->type;

		my $primer = $project_type;
		
		my $seq = DNALC::Pipeline::Phylogenetics::Pair->retrieve($record->sequence_id)->consensus;
        # remove any dashes from the sequence which may have been introduced by the aligner
		$seq =~ s/-//g;

		# Get the organism name, need it for the annotation
        my $data = $self->_parse_json($record->data);
        my $organism = $data->{genus} . ' ' . $data->{species};

		# Get the translation table to be used
		my $trans_table = $data->{trans_table};
		print STDERR "trans_table: $trans_table\n";

		# Get the isolation source, need it for the annotation
		my $isolation_source = $data->{isolation_source};

		# Create the annotation
		my $annotation = DNALC::Pipeline::Barcode::Annotation::annotate_barcode($seq, $primer, $organism, $trans_table, $isolation_source);

		# Create and populate the Feature Table
		# (only if you got defined output from the annotate_barcode function)
		if ($annotation) {
			my $feature_table = $self->{work_dir} . "/$seq_id/$id.tbl";
			my $outfile = IO::File->new;
			if ($outfile->open($feature_table, "w")){
				print $outfile ">Feature $id Table1\n";
				print $outfile $annotation;
				undef $outfile;
				print STDERR "Feature Table created: " . $self->{work_dir} . "/$seq_id/$id.tbl\n";
				return {status => 'success'};
			}
			else {
				print STDERR "FAILED to create Feature Table: ", $!, "\n";
				$self->_email_admin($record, "FAILED to create Feature Table: $!");
				return {status => 'error', 'message' =>  "FAILED to create Feature Table: $!" };
			}
		}
		else {
			print STDERR "FAILED to generate annotation: ", $!, "\n";
		    $self->_email_admin($record, "FAILED to generate annotation: $!");
			return {status => 'error', 'message' =>  "FAILED to generate annotation: $!" };

		}

	}

	# ---------------------------------------
	# Run tbl2asn
	#
	sub run_tbl2asn {
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $id = $record->specimen_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";
		my $template = $self->{work_dir} . "/$seq_id/template.sbt";
		print STDERR "tbl2asn command: /usr/local/bin/linux.tbl2asn", "-t", $template, "-p", $work_dir, "-o", "$work_dir/genbank.asn -V c\n";	
		my $status = system("/usr/local/bin/linux.tbl2asn", "-t", $template, "-p", $work_dir, "-o", "$work_dir/genbank.asn", "-V", "c");
		if (($status >>=8) != 0) {
			print STDERR "FAILED: tbl2asn\n";	
			$self->_email_admin($record, "FAILED: tbl2asn");
			return {status => 'error', 'message' => "FAILED: tbl2asn" };
		}
		else{
			print STDERR "tbl2asn ran successfully, created file: $work_dir/genbank.asn\n";
			return {status => 'success'};
		}
		
	}

	# ---------------------------------------
	# Get trace files, put them in a .tar.gz archive
	# in the working directory. Also create a 
	# trace metadata file called trace-info.txt.
	#
	sub prep_trace_file {
		my ($self, $record) = @_;
		my $seq_id = $record->sequence_id;
		my $specimen_id = $record->specimen_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";
		
		my $tar = Archive::Tar->new;
		
		my $pair_id;
		my $forward;
		my $reverse;
		my ($boldseq) = DNALC::Pipeline::Phylogenetics::BoldSeq->search(bold_id => $record->id);
		if ($boldseq) {
			$pair_id = $boldseq->pair_id;
		}
		
		if ($pair_id){
			my ($forward_ps) = DNALC::Pipeline::Phylogenetics::PairSequence->search(pair_id => $pair_id, strand=> "F");
            my ($reverse_ps) = DNALC::Pipeline::Phylogenetics::PairSequence->search(pair_id => $pair_id, strand=> "R");
            $forward = $forward_ps->seq if $forward_ps;
            $reverse = $reverse_ps->seq if $reverse_ps;
		}

		
		if ($forward && $reverse) {
			my $f_file = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($forward->file_id);
            my $r_file = DNALC::Pipeline::Phylogenetics::DataFile->retrieve($reverse->file_id);
            my $f_file_path = $f_file->get_file_path if $f_file;
			my $r_file_path = $r_file->get_file_path if $r_file;
            my $f_file_name = basename $f_file_path;
	        my $r_file_name = basename $r_file_path;
			my $file_dir = dirname $f_file_path;
			
			# Changing into the directory where the trace files are located
			# so that the tar archive does not contain any sub directories
			chdir $file_dir;

			# Create .tar.gz archive with both trace files (forward and reverse)
			if (-f $f_file_name && -f $r_file_name){
				my $tfile = Archive::Tar::File->new( file => $f_file_name );
				$tfile->rename('trace_f.ab1');
				$tar->add_files($tfile);
				
				$tfile = Archive::Tar::File->new( file => $r_file_name );
				$tfile->rename('trace_r.ab1');
				$tar->add_files($tfile);

				#$tar->add_data("trace_f.ab1", $f_file_name, {type => 'file'});
				#$tar->add_data("trace_r.ab1", $r_file_name, {type => 'file'});
				if ($tar->write("$work_dir/trace-data.tar.gz", COMPRESS_GZIP)){
					print  STDERR "tar file of trace files created: $work_dir/trace-data.tar.gz", $/;
				}
				else{
					$self->_email_admin($record, "FAILED to create trace-data.tar.gz: $!");
					print STDERR "FAILED to create trace-data.tar.gz: ", $!, "\n";
					return {status => 'error', 'message' => "FAILED to create trace-data.tar.gz: $!" };
				}
			}
			else {
				print STDERR "FAILED: \$f_file_name: $f_file_name and/or \$r_file_name: $r_file_name not found in dir $file_dir", $/;
				$self->_email_admin($record, "FAILED: \$f_file_name: [$f_file_name] and/or \$r_file_name: [$r_file_name] not found in dir $file_dir");
				return {status => 'error', 'message' => "FAILED: \$f_file_name: [$f_file_name] and/or \$r_file_name: [$r_file_name] not found in dir $file_dir" };
			}		
			
			# Get Base Caller info for both trace files (forward and reverse)
			# We need this for the trace metadata file (created next)
            my $abif = Bio::Trace::ABIF->new();
            my $bcf = "";
            my $bcr = "";
            if ($abif->open_abif($f_file_name) && $abif->is_abif_format){
                $bcf = sprintf("%s %s", $abif->basecaller_bcp_dll || '?',
                    $abif->basecaller_version || '?');
                $abif->close_abif;
            }
            if ($abif->open_abif($r_file_name) && $abif->is_abif_format){
                $bcr = sprintf("%s %s", $abif->basecaller_bcp_dll || '?',
                    $abif->basecaller_version || '?');
                $abif->close_abif;
            }
			
			# Once finished working with the trace files, change directories
			# back to our regrular working dir
			chdir $self->{pwd};
			
			# Create column headers which is needed for the trace metadata file
			my @column_headers_array = ("Template_ID", "Trace_file", "Trace_format",
				"Center_project", "Program_ID", "Trace_end");
			my $column_headers = join("\t", @column_headers_array);
			
			# Create trace metadata file, will hold data for both trace files (f & r)
			my $trace_info = $work_dir . "/trace-info.txt";
			my $outfile = IO::File->new;
			if ($outfile->open($trace_info, "w")){
				print $outfile $column_headers, "\n";
				print $outfile $specimen_id, "\t", "trace_f.ab1", "\t", "ABI\t", "DNAS\t", "$bcf\t", "F\n";
				print $outfile $specimen_id, "\t", "trace_r.ab1", "\t", "ABI\t", "DNAS\t", "$bcr\t", "R";
				undef $outfile;
				print STDERR "trace-info.txt created: $work_dir/trace-info.txt\n";
				return {status => 'success'}
			}
			else {
				print STDERR "FAILED to create file trace-info.txt: ", $!, "\n";
				$self->_email_admin($record, "FAILED to create file trace-info.txt: $!");
				return {status => 'error', 'message' => "FAILED to create file trace-info.txt: $!" };
			}
			
        }
		else {
			print STDERR "FAILED at prep_trace_files, \$forward: [$forward] & \$reverse: [$reverse] not there...";
			$self->_email_admin($record, "FAILED at prep_trace_files, \$forward: [$forward] & \$reverse: [$reverse] not there...");
			return {status => 'error', 'message' => "FAILED at prep_trace_files, \$forward: [$forward] & \$reverse: [$reverse] not there..." };
		}

	}
	
	# ---------------------------------------
	# Wrap trace-data.tar.gz, genbank.asn, and 
	# trace-info.txt in a tar file for submission
	#
	sub prep_submission_file {
		my ($self, $record) = @_;
		my $specimen_id = $record->specimen_id;
		my $seq_id = $record->sequence_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";

		my $tar = Archive::Tar->new;

		chdir $work_dir;
		if (-f "genbank.asn" && -f "trace-data.tar.gz" && -f "trace-info.txt"){
			$tar->add_files("genbank.asn", "trace-info.txt", "trace-data.tar.gz");
			if ($tar->write("$specimen_id.tar")){
				chdir $self->{pwd};
				print STDERR "Final tar file created: $work_dir/$specimen_id.tar", $/;
				return {status => 'success'};
			}
			else {
				chdir $self->{pwd};
				print STDERR "FAILED to create final tar file for submission: ", $!, $/;
				$self->_email_admin($record, "FAILED to create final tar file for submission: $!");
				return {status => 'error', 'message' => "FAILED to create final tar file for submission: $!" };
			}
		}

	}

	# ---------------------------------------
	# FTP the submission file
	#
	sub submit {
		my ($self, $record) = @_;
		my $specimen_id = $record->specimen_id;
		my $seq_id = $record->sequence_id;
		my $work_dir = $self->{work_dir} . "/$seq_id";
		my $user = $self->{ftp_user};
		my $pw = $self->{ftp_pw};
		
		my $ftp = Net::FTP->new("ftp-private.ncbi.nlm.nih.gov", Debug=>0, Passive => $self->{ftp_passive})
			or do {
				$self->_email_admin($record, "Cannot connect to: ftp-private.ncbi.nlm.nih.gov: $@");
				return {status => 'error', 'message' => "Cannot connect to: ftp-private.ncbi.nlm.nih.gov: $@" };
			};

		$ftp->login($user, $pw)
			or do {
				$self->_email_admin($record, "Cannot login (ftp): " . $ftp->message);
				return {status => 'error', 'message' => "Cannot login (ftp): " . $ftp->message };
			};

		$ftp->binary;

		$ftp->put("$work_dir/$specimen_id.tar")
			or do {
					$ftp->quit;
					$self->_email_admin($record, "ftp put failed: " . $ftp->message);
					return {status => 'error', 'message' => "ftp put failed: " . $ftp->message };
			};
		my $fname = "$specimen_id.tar";

		my ($info) = grep /$fname/, $ftp->dir;
		print STDERR '**: ', $info, $/;

		$ftp->quit;			
		return {status => 'success'};
	}
		
	# ---------------------------------------
	# 
	sub validate_submission {
	 	my ($self, $record) = @_;
        my $specimen_id = $record->specimen_id;
        my $user = $self->{validation_user},
		
		my $ht = HTTP::Tiny->new(timeout => 30);
		my $response = $ht->get("http://www.ncbi.nlm.nih.gov/WebSub/api/?user=$user&file=$specimen_id.tar");
		#print STDERR "Validation URL: http://www.ncbi.nlm.nih.gov/WebSub/api/?user=$user&file=$specimen_id.tar\n";
		my $parsed_response;

		if ($response->{success} && length $response->{content}) {
    		$parsed_response = XMLin($response->{content});
			if ($parsed_response->{response}->{code} eq "FAIL"){
				print STDERR "FAILED VALIDATION", $/;

				$self->_email_admin($record, 'FAILED Validation - check email');
				return {status => 'error', 'message' => "FAILED Validation - check email" };
				#}
    		}
			elsif ($parsed_response->{response}->{code} eq "PASS_WITH_WARNINGS") {
				print STDERR "PASSED WITH WARNINGS\n";
				$self->_change_status($record, "Passed With Warnings");
				$self->_email_user($record);
				return {status => 'success'};
			}
			elsif ($parsed_response->{response}->{code} eq "PASS"){
				print STDERR "PASSED VALIDATION! \n";
				$self->_change_status($record, "Passed validation");
				$self->_email_user($record);
				return {status => 'success'};
			}
			else {
				print STDERR "UNENCOUNTERED RESPONSE CODE FROM VALIDATION: ", $parsed_response->{response}->{code};
				$self->_email_admin($record, "Unencountered response code: " . $parsed_response->{response}->{code} . ' - check email');
				return {status => 'error', message => "Unencountered response code: " . $parsed_response->{response}->{code}};
			}
		}
	}

	# ----------------------------------------
	# Change status from Pending to dir_name
	# where submission files are located
	#
	sub _change_status{
		my ($self, $record, $status) = @_;
		$record->status($status);
		$record->update;
	}

	# ---------------------------------------
	# Email the user on (successful) submission.
	#
	sub _email_user {
		my ($self, $record) = @_;
		my $pid = $record->project_id;
		my $uid = DNALC::Pipeline::Phylogenetics::Project->retrieve($pid)->user_id;
		my $user_email = DNALC::Pipeline::User->retrieve($uid)->email;

		my $message = "Thank you for submitting your sequence. This email is to confirm that your submission has been processed successfully. Please note however this does not mean your sequence has been successfully accepted and published to GenBank. GenBank will review all submissions, typically within 48 hours, at which point you will receive another confirmation email. Your DNA Subway submission ID is ". $record->{specimen_id} . ". Please keep this for future reference.\n\nThank you,\nThe DNA Subway Team";
		
		DNALC::Pipeline::App::Utils->send_email({
                To => $user_email,
                Message => $message,
                Subject => 'Your DNA Subway Submission to GenBank',
            });
	}

	
	# ----------------------------------------
	# Email the admin on failed submission attempt
	#
	sub _email_admin{
		my ($self, $record, $message) = @_;
		my $specimen_id = $record->specimen_id;
		
		$message = "ID: $record\nSpecimen ID: $specimen_id \nMessage:\n$message";

		DNALC::Pipeline::App::Utils->send_email({
				To => 'mkhalfan@cshl.edu, ghiban@cshl.edu',
				Message => $message,
				Subject => 'FAILED GB Submission',
			});
	}

	# ----------------------------------------
	# Run Everything From Here
	#
	sub run {
		my ($self, $id) = @_;

		my $bail_out = sub { return {status => 'error', 'message' => shift} };		

		# Run create_dir (doesn't return anything)
		$self->create_dir($id);

    	# Run create_fasta
		my $st = $self->create_fasta($id);

		# Run create_smt
		if ($st->{status} eq 'success'){
			$st = $self->create_smt($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}

    	# Run make_template
   		if ($st->{status} eq 'success'){
        		$st = $self->make_template($id);
		}
		else {
        		return $bail_out->("ID: $id ERROR: $st->{message}");
   	 	}
 
		# Run create_feature_table
        if ($st->{status} eq 'success'){
                $st = $self->create_feature_table($id);
        }
        else {
                return $bail_out->("ID: $id ERROR: $st->{message}");
        }
		# Run run_tbl2asn
		if ($st->{status} eq 'success'){
			$st = $self->run_tbl2asn($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}

		# Run prep_trace_file
		if ($st->{status} eq 'success'){
			$st = $self->prep_trace_file($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}

		# Run prep_submission_file
		if ($st->{status} eq 'success'){
			$st = $self->prep_submission_file($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}
		
		# Run submit
		if ($st->{status} eq 'success'){
			$st = $self->submit($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}

		# Run validate_submission
		if ($st->{status} eq 'success'){
			$st = $self->validate_submission($id);
		}
		else {
			return $bail_out->("ID: $id ERROR: $st->{message}");
		}

		return {status => $st->{status}, message => $st->{message}};
	}
}

1;


