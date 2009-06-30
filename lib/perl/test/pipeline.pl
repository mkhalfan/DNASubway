#!/usr/bin/perl -w

use DNALC::Pipeline::User ();
use DNALC::Pipeline::Config ();
use DNALC::Pipeline::Project ();
use DNALC::Pipeline::App::WorkflowManager ();
use DNALC::Pipeline::Utils qw(random_string);
use DNALC::Pipeline::Chado::Utils ();
use Data::Dumper;

use strict;

$ENV{GMOD_ROOT} = '/usr/local/gmod';

#-----------------------------------------------------------------------------
my $input_file = '/home/ghiban/work/100k/B.fasta';
my $organism = 'Narcissus pseudonarcissus';
my @subnames = split /\s/, $organism;
my $common_name = 'daffodil';
#-----------------------------------------------------------------------------

die "Input file not found: $input_file", $/ unless (-f $input_file);

my $username = $ARGV[0] || 'guest';
if (!$username || $username =~ /[^a-z0-9_-]/i) {
	print STDERR  "Username missing or not well formated.", $/;
	exit 0;
}

my ($u) = DNALC::Pipeline::User->search( username => $username);

#create project
my $proj = eval {
		DNALC::Pipeline::Project->create({
			user_id => $u->id,
			name => 'Project name: '. random_string(4, 15),
			organism => $organism,
			common_name => $common_name,
			crc => '',
		});};

if ($@) {
	die "Error: $@", $/;
}
else {
	warn "project_created: id = ", $proj, ",\tname = ", $proj->name, $/;

	# create projects work directory
	if ($proj->create_work_dir) {
		warn "project's work_dir: ", $proj->work_dir, $/;
		$proj->dbi_commit;
	}
	else {
		warn "Failed to create work_dir for project [$proj]", $/;
		$proj->dbi_rollback;
		exit 0;
	}
}

my $cf = DNALC::Pipeline::Config->new;
my $pcf = $cf->cf('PIPELINE');

# CHADO - new db/profile
my $cutils = DNALC::Pipeline::Chado::Utils->new(
		username => $username,
		dumppath => $pcf->{GMOD_DUMPFILE},
		profile => $pcf->{GMOD_PROFILE},
		organism_string => join('_', @subnames). '_' . $common_name,
		gbrowse_template => $pcf->{GBROWSE_TEMPLATE},
		gbrowse_confdir  => $pcf->{GBROWSE_CONF_DIR},
	);

eval {
	$cutils->create_db();
};
if ($@)  {
	print STDERR  "CHADO DB already exists. skipping...", $/;
}
print STDERR Dumper( $cutils), $/;

my $conffile_ok = $cutils->create_conf_file( $proj->id );
print STDERR "Created file = ", $conffile_ok, $/;
my $new_profile = sprintf("%s_%d", $username, $proj->id);

# !!!!
# read data from new file - inserting the data into the users's database...
# !!!!
$cutils->profile($new_profile);
$cutils->insert_organism;

my $wfm = DNALC::Pipeline::App::WorkflowManager->new( $proj );

#print STDERR Dumper( \$wfm), $/;

my $upload_st = $wfm->get_status('upload_fasta');

if ( $upload_st->name eq 'Not processed') {
	my $fasta = $wfm->upload_sequence($input_file);

	$upload_st = $wfm->get_status('upload_fasta');
}

print STDERR "U_ST = ", $upload_st->name , $/;

if ( $upload_st->name eq 'Done') {
	my $st;
	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_repeat_masker;
 	my $rm_st = $wfm->get_status('repeat_masker');
 	print STDERR "RM_ST = ", $rm_st->name, ($/ x 2);

	#-------------------------------------

 	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_augustus;
 	#print STDERR Dumper( $st ), $/;
 	my $a_st = $wfm->get_status('repeat_masker');
 	print STDERR  "AUGUSTUS_ST = ", $a_st->name, $/;

	#-------------------------------------
 	print STDERR  '-' x 20 , $/;
 	$st = $wfm->run_trna_scan;
 	print STDERR Dumper( $st ), $/;
 	my $t_st = $wfm->get_status('trna_scan');
 	print STDERR "TRNA_SCAN_ST = ", $t_st->name, ($/ x 2);
	#-------------------------------------
	print STDERR  '-' x 20 , $/;
	$st = $wfm->run_fgenesh;
	print STDERR Dumper( $st ), $/;
	my $f_st = $wfm->get_status('fgenesh');
	print STDERR "FGNESH_ST = ", $f_st->name, ($/ x 2);
	#-------------------------------------
}

#let apache be able to work with projects files..
system('chmod -R a+w ' . $proj->work_dir);

# 1st create GBrowse conf file & DB dir for this project
$cutils->create_gbrowse_conf($proj->id, $pcf->{GBROWSE_DB_DIR});

# 2nd create GFF file
my $gff_file = '';
my $gff3_files = $proj->get_available_gff3_files || [];

my @params = ();
for my $gff (@$gff3_files) {
	push @params, ('-g', $gff);
}
if (@params) {
	my $gff_merger = $pcf->{EXE_PATH} . '/gff3_merger.pl';
	$gff_file = $proj->work_dir . '/gff3.gff';
	my @args = ($gff_merger, @params, '-f', $proj->fasta_file, '-o', $gff_file);

	system (@args) && die "Error: $!\n";
	chmod 0666, $gff_file;

	my $slink = $pcf->{GBROWSE_DB_DIR} . '/' . $username . '/' . $proj->id . '/gff3.gff' ;
	print STDERR  "SYMLINK $gff_file -> ", $slink, $/;
	symlink $gff_file, $slink;
	chmod 0666, $slink;
}

print $/;
print 'MERGED GFF FILE = ', $gff_file, $/;
print $/;

warn @$gff3_files;

my $load_fasta_command="perl /var/www/bin/load_fasta.pl --username guest --profile "
                             .$username."_".$proj->id." --fastapath ".$proj->fasta_file;
warn $load_fasta_command;
system($load_fasta_command);

for my $file (@$gff3_files) {
    warn $file;
    my $gff_load_command = "gmod_bulk_load_gff3.pl -a --noexon --dbprof ".$username."_".$proj->id." -g $file";
    warn $gff_load_command;
    system($gff_load_command);
}
