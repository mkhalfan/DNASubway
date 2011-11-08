#!/usr/local/bin/perl

use strict;
use DNALC::Pipeline::NGS::Project;
use DNALC::Pipeline::NGS::Job;
use DNALC::Pipeline::NGS::JobParam;
use DNALC::Pipeline::NGS::DataFile;
use DNALC::Pipeline::NGS::DataSource;

if (1){
	my $proj = DNALC::Pipeline::NGS::Project->create({
		user_id => 693,
		name => 'testing db project x',
		organism => 'Staphylococcus areus',
		common_name => 'staph a',
		description => 'my eigth test project',
		type => 'transcript abundance',
	});
}

if (0){
	my $job = DNALC::Pipeline::NGS::Job->create({
		api_job_id => 536,
		project_id => 8,
		task_id => 5,
		status_id => 1,
		user_id => 693,
		deleted => 'FALSE',
	});
}

if(0){
	my $param = DNALC::Pipeline::NGS::JobParam->create({
		job_id => 13,
		type => 'param',
		name => 'max_num_alignments_allowed',
		value => '10000',
	});
}

if(0){
	my $ds = DNALC::Pipeline::NGS::DataSource->create({
		type => 'bowtie',
	});
}

if(0){
	my $df = DNALC::Pipeline::NGS::DataFile->create({
		project_id => 7,
		source_id => 1,
		file_name => 'see.fastq',
		file_path => '/mkhalfan/analysis/new/',
		file_type => 'fastq',		
	});
}

if(0){	
	my $to_del = DNALC::Pipeline::NGS::Project->retrieve(1);
	$to_del->delete;
}

