#!/usr/bin/perl 
use common::sense;

use Data::Dumper;
use DNALC::Pipeline::App::ProjectManager ();
use DNALC::Pipeline::App::WorkflowManager ();
use File::Temp ();

$ENV{GMOD_ROOT} = '/usr/local/gmod';


sub change_seq_id {
	my (%args) = @_;

	my $in_file  = $args{in};
	my $out_file = $args{out};
	print STDERR  $in_file, " >>>>> ", $out_file, $/;
	my $in = new IO::File($in_file);
	if ($in) {
		my $out = new IO::File("> $out_file");
		next unless $out;
		while (my $line = <$in>) {
			$line =~ s/^>$args{source_cn}/>$args{dest_cn}/g;
			print $out $line;
		}
		undef $in;
		undef $out;
	}
}

my $user_id = 90;
#my $pid = 759;
my $pid = 797;

#0. get info about the source project
# source
my $spm = DNALC::Pipeline::App::ProjectManager->new($pid);
Carp::croak unless $spm;

# XXX : make sure the source is public

my %analyses = (
		repeat_masker => 'RepeatMasker',
		augustus => 'Augustus',
		fgenesh => 'FGenesH',
		snap => 'Snap',
		trna_scan => 'TRNAScan',
		blastn => 'Blast',
		blastx => 'Blast',
	);


#1. create a Bio::Seq based on the source/fasta file 
my $seqio = Bio::SeqIO->new( '-format' => 'fasta' , -file => $spm->fasta_file );
my $seq = $seqio->next_seq;
#$seq->display_id('gogu');
#$seq->primary_id('gogu');

#print STDERR Dumper( $seq ), $/;


#2. create new project, based on the original
# destination
my $dpm;
if (1) {
	$dpm = DNALC::Pipeline::App::ProjectManager->new();
	my $name = "Copy of " . $spm->project->name;
	my $tries = 1;
	while ($tries++ <= 10) { # hardcoded :(
		my $p = $dpm->search( user_id => $user_id, name => $name);
		last unless $p;
		$name = "Copy #$tries of " . $spm->project->name;
		print STDERR  "** $name", $/;
	}
	my $st = $dpm->create_project ({
				user_id => $user_id,
				seq => $seq,
				name => $name,
				organism => $spm->project->organism,
				common_name => $spm->project->common_name,
				sample => '',
				clade => $spm->project->clade,
				description => $spm->project->description,
			});

	unless ($st->{status} eq 'success') {
		Carp::croak $st->{message}, $/;
	}
}
else {
	$dpm = DNALC::Pipeline::App::ProjectManager->new(766);
}
print STDERR  "New PID = ", $dpm->project, $/;

#3. copy routines gff files.
#3.1. adjust the names to the new project info

my $pcf = $spm->config;
my $swfm = DNALC::Pipeline::App::WorkflowManager->new( $spm->project );
my $dwfm = DNALC::Pipeline::App::WorkflowManager->new( $dpm->project );

my $source_cn = $spm->cleaned_common_name;
my $dest_cn = $dpm->cleaned_common_name;

my @done_analyses = $swfm->get_done;
#print STDERR "@done_analyses", $/;
for my $a (@done_analyses) {
	next unless exists $analyses{$a};
	print "\n[", $a, '] ', $analyses{$a}, $/;
	my $rclass = "DNALC::Pipeline::Process::$analyses{$a}";
	my $rt = $rclass->new( $spm->work_dir, $a =~ /^blast/ ? $a : $spm->project->clade );
	my $dest_rt = $rclass->new( $dpm->work_dir, $a =~ /^blast/ ? $a : $spm->project->clade );

	my $gff_to_parse = $rt->get_gff3_file("dont_parse");
	my $out_file = $dest_rt->get_gff3_file("dont_parse");

	print STDERR  "src gff = ", $gff_to_parse, $/;
	print STDERR  "new gff = ", $out_file, $/;

	my $out = new IO::File("> $out_file");
	my $in = new IO::File($gff_to_parse);
	if ($in) {
		while (my $line = <$in>) {
			my @tokens = split /\t/, $line;
			next if scalar(@tokens) != 9;
			$line =~ s/$source_cn/$dest_cn/g;
			print $out $line;
		}
		undef $in;
	}
	undef $out;
	
	#load_analysis_results
	#print STDERR  "size= ", -s $out_file, $/;
	if (-f $out_file && !-z $out_file) {
		system( $pcf->{EXE_PATH} . '/load_analysis_results.pl', 
				'--username', $dpm->username,
				'--profile', $dpm->chado_user_profile,
				'--algorithm', $a,
				'--gff', $out_file,
		) == 0 
		or do {
			Carp::carp "Error: Unable to load gff file: ", $out_file;
			next;
		};
	}

	#mark routine as done in the dest project
	$dwfm->set_status($a, 'done');
}

if (@done_analyses) {
	# copy & update masked fasta files
	my @files = (
			'REPEAT_MASKER/output/fasta.fa.masked',
			'REPEAT_MASKER2/output/fasta.fa.masked',
		);

	my $dest_rm2 = $dpm->work_dir . '/REPEAT_MASKER2';
	unless (-e $dest_rm2) {
		mkdir $dest_rm2;
		mkdir $dest_rm2 . '/output';
	}
	for my $masked_fasta (@files) {
		change_seq_id(in => $spm->work_dir . '/' . $masked_fasta,
					out => $dpm->work_dir . '/' . $masked_fasta,
					source_cn => $source_cn,
					dest_cn => $dest_cn
				);
	}

	# dump user data
	my $fh  = File::Temp->new(TEMPLATE => '/tmp/user-data-XXXXX', SUFFIX => '.gff3');
	my $user_annot_file = $fh->filename;

	print STDERR  "\n\nDumping user data in: ", $user_annot_file, $/;

	my @cmd = ($pcf->{EXE_PATH} . '/dump_user_annotations.pl', 
					'--profile', $spm->chado_user_profile,
					'--seqid', $source_cn,
					'--file', $user_annot_file
				);
	print STDERR "@cmd", $/;
	my $rc = system ( @cmd);
	print STDERR  "RC = ", $rc , $/;

	if ($rc == 0 && -f $user_annot_file && -s $user_annot_file) {
		my $fh2 = File::Temp->new(TEMPLATE => '/tmp/user-data-XXXXX', SUFFIX => '.gff3', UNLINK => 0);
		my $user_annot_file2 = $fh2->filename;
		print STDERR  "Dumping user data in: ", $user_annot_file2, $/;
		change_seq_id(in => $user_annot_file,
					out => $user_annot_file2,
					source_cn => $source_cn,
					dest_cn => $dest_cn
				);

	}

}

system('chmod', '-R', 'a+w', $dpm->work_dir);

__END__

	my $user_annot_file = "/tmp/user_data_$pid.gff";
	my $gff_file = "/tmp/gff_$pid.gff";

	my $user_annot_file = "/tmp/user_data_$pid.gff";
	my $trimmed_common_name = $spm->cleaned_common_name;

	my @cmd = ($pcf->{EXE_PATH} . '/dump_user_annotations.pl', 
					'--profile', $spm->chado_user_profile,
					'--seqid', $trimmed_common_name,
					'--file', $user_annot_file
				);
	#print STDERR "@cmd", $/;
	my $rc = system ( @cmd);
	#print STDERR  "RC = ", $rc , $/;

	if ($rc == 0 && -f $user_annot_file) {
		#print STDERR  "User file = ", $user_annot_file, $/;
		push @params, ('-g', $user_annot_file);
	}

	my $gff_merger = $pcf->{EXE_PATH} . '/gff3_merger.pl';
	my @args = ($gff_merger, @params, '-f', $dpm->fasta_file, '-o', $gff_file, '-r');
	print STDERR "@args", $/;
	print STDERR  $gff_file, $/;

	system (@args) && Carp::croak "Error: $!\n";
	if (-f $gff_file) {
		#
	}
}
else {
	print "Error: No gff3 files were found! Perhaps no routine has been called.";
}

