
function NGS (id) {
	this.pid = id;
	this.windows = [];
	this.status_check_enabled = null;
	
	this.titles = {
		ngs_tophat : "TopHat",
	};
	
};

NGS.prototype.get_status = function(op) {
	if (! $(op + '_st'))
		return '';
	var cname = $(op + '_st').className;
	return cname.replace('conIndicatorGL_', '');
};

NGS.prototype.set_status = function(op, status) {

		// when do we need to set the window title??
		//var title = this.titles[op] || '??';

		var ind = $(op + '_st');
		ind.removeClassName(ind.className);

				
		if (op != 'ngs_fastqc') {
			var b = $(op + '_btn');
			b.onclick = function(){ ngs.launch(op); };
		}
		
		if (status == 'processing') {
			ind.addClassName('conIndicatorGL_processing');
			ngs.enable_status_check();
		}
		else if (status == 'done') {
			ind.addClassName('conIndicatorGL_done');
		}
		else if (status == 'not-processed') {
			ind.addClassName('conIndicatorGL_not-processed');
		}
		else if (status == 'disabled') {
			ind.addClassName('conIndicatorGL_disabled');
			b.onclick = null;
		}
	};

NGS.prototype.launch = function(what, where, title) {

	var tool = what;
	var re = /^ngs_/;
	if (tool && re.test(tool)) {
		tool = tool.replace(re, '');
	}
	var urls = {
			//data: ['/project/ngs/tools/manage_data?pid=', 'Manage data'],
			ngs_fastqc: ['/project/ngs/tools/manage_data?pid=', 'Manage data'],
			ngs_cufflinks: ['/project/ngs/tools/job_list_' + tool + '?pid=', 'Cufflinks'],
			ngs_cuffdiff: ['/project/ngs/tools/job_list_' + tool + '?pid=', 'Cuffdiff'],
			ngs_tophat: ['/project/ngs/tools/job_list_' + tool + '?pid=' , 'TopHat'],
			ngs_fxtrimmer: ['/project/ngs/tools/job_list_' + tool + '?pid=' , 'FastX Toolkit'],
			ngs_cuffmerge: ['/project/ngs/tools/job_list_' +tool  + '?pid=' , 'Cuffmerge']
		};

	var host = window.location.host;
	var uri = what && urls[what]
					? 'http://' + host + urls[what][0] + $('pid').value
					: where;
	var window_title = title ? title : urls[what] ? urls[what][1] : null;
	
	var options = null;
	
	this.windows[what] = openWindow( uri, window_title, options);
};

NGS.prototype.close_window = function(id) {
	this.windows[id] && this.windows[id].destroy();
};


NGS.prototype.add_data = function() {
	var data = [];
	$$('input[type=checkbox]').each(function(el) {
		if (el.checked) {
			$('form_add_data').submit();
		}
	});
};

// not using this do_qc funtion anymore
NGS.prototype.do_qc = function(id) {
	new Ajax.Request('/project/ngs/tools/do_qc', {
		method:'get',	
		parameters: {'pid': this.pid, 'f': id},
		onSuccess: function(transport){
				var r = transport.responseText.evalJSON();
				if (r && r.status == 'success') {
					$('qcst_' + id).update('Running');
					ngs.enable_status_check();
				}
				else {
					alert("QC was not launched :(");
				}
			},
		onFailure: function(){
				alert('Something went wrong!\nAborting...');
			}
	});
	
	$('qcst_' + id).update('');
};

NGS.prototype.enable_status_check = function() {
	// Here we check if there is already an instance of ngs_status_check_enabled
	// we test this by seeing if the .timer property has a value, if it does (not null)
	// then it is enabled. 
	// TODO: Test an alternate method of setting ngs.status_check_enabled = null when you
	// disable the status checking. Thereby you only have to check if the object
	// is null rather than having to check the timer property. But it's working as is for now. 
	if (ngs.status_check_enabled != null && ngs.status_check_enabled.timer != null) {
		return;
	}
	var pe = new PeriodicalExecuter(function(pe) {
			ngs.check_status();
		}, 15);
	ngs.status_check_enabled = pe;
};

NGS.prototype.disable_status_check = function() {
	if (ngs.status_check_enabled != null)
		ngs.status_check_enabled.stop();
};

NGS.prototype.check_status = function() {
	new Ajax.Request('/project/ngs/tools/tool_stats', {
		method:'get',	
		parameters: {'pid': this.pid, 'x': new Date().getTime()},
		onSuccess: function(transport){
				var r = transport.responseText.evalJSON();
				if (r && r.status == 'success') {
					var processing = 0;
					$H(r.tools).keys().each(function(t) {
						//if (t != 'ngs_fastqc' && t != 'ngs_fxtrimmer') {
						if (t != 'ngs_cuffmerge') {
							//console.info(t + ' ' + ngs.get_status(t) + ' ' + r.tools[t]);
							if (ngs.get_status(t) != r.tools[t]) {
								console.info('  ++ =>' + t);
								console.info(ngs.get_status(t));
								console.info(r.tools[t]);
								ngs.set_status(t, r.tools[t]);
								if (ngs.windows[t]) {
									try {
										ngs.windows[t].iframe.contentDocument.location.reload();
										console.info('  +- => reloaded "popup" window for ' + t);
									} catch (e) {
										console.info('  +- => unable to reloaded "popup" window for ' + t);
										console.info('  +- => ' + e);
									};
								}
							}
							if (r.tools[t] == 'processing')
								processing += 1;
						}
					});
					// no more status checking if nothing is processing
					if (!processing)
						ngs.disable_status_check();
				}
				else {
					console.warn("Error: " + r.message);
				}
			},
		onFailure: function(){ alert('Something went wrong!\nAborting...');}
	});
};

// TODO should pass the name of the input form (which represents the file to be processed)
// if you know the fid, do we really need the 'a' object?!
//
NGS.prototype.basic_run = function(tool, pid, fid, a, is_input) {
	var cell = a.up();
	cell.update('<img src="/images/ajax-loader-2.gif" style="width:12px;padding-left:5px;" class="alpha">');
	
	var params = {'pid': pid, 'basic_run': 1};
	if (tool == 'fxtrimmer') {
		params['seq1'] = fid;
	}
	else if (tool == 'fastqc') {
		params['input'] = fid;
	}
	else {
		params['query1'] = fid;
	}

	if (tool == 'tophat' && is_input) {
		//this.check_tophat(is_input);
	}
	
	new Ajax.Request('/project/ngs/tools/app_' + tool, {
		method:'post',	
		parameters: params,
		onSuccess: function(transport){
				var r = transport.responseText.evalJSON();
				if (r && r.status == 'success') {
					// Add a processing icon only if the job status is 'processing'
					var processing_icon = "";
					if (r.job_status == 'processing') {
						processing_icon = ' <img src="/images/ajax-loader-2.gif" width="12px;">';
					}
					if (tool != 'fastqc') {
						// Default last row is the file row
						var lastRow = $('file' + fid);
						// Get the last row in the current files' jobs listing
						var childRows = $$('[parent="file' + fid + '"]');
						// If there are child rows, update last row to be 
						// the last row of the child jobs of this file
						if (childRows.length > 0) {
							lastRow = childRows[childRows.length - 1];
						}
						lastRow.insert({after:'<tr id="job-' + r.job_id + '" class="highlight" parent="file' + fid + '"><td></td><td>' + r.job_name + '</td><td></td><td></td><td>' + r.job_status + processing_icon + '</td><td></td></tr>'});
						Element.addClassName.delay(0.15, 'job-' + r.job_id, 'fade');
						cell.update('<span class="disabled_text_submit">Run</span>');
					}
					else {
						cell.update(r.job_status + processing_icon);
					}
					// inform the panel about this new job
					top.ngs.set_status('ngs_' + tool, 'processing');
				}
				else {
					console.warn("Error: " + r.message);
					cell.upadte('<a onclick="javascript:ngs.basic_run(' + tool + ', ' + pid + ', ' + fid + ', this)" href="javascript:;" class="text_submit">Run</a>');
				}
			},
		onFailure: function(){ 
			alert('Something went wrong!\nAborting...');
			cell.upadte('<a onclick="javascript:ngs.basic_run(' + tool + ', ' + pid + ', ' + fid + ', this)" href="javascript:;" class="text_submit">Run</a>');
		}
	});
};

NGS.prototype.toggle_params = function(){
	$('app_parameters').toggle();
	$('show_params').toggle();
	$('hide_params').toggle();
}

NGS.prototype.check_add_data = function() {
	var form = $('form_add_data');
	var files = form.getInputs('checkbox');
	var has_files = false;
	if (files) {
		for (var idx = 0; idx < files.length; idx++) {
			var cb = files[idx];
			if (cb && cb.checked) {
				has_files = true;
			}
		}
	} 
	if (has_files) {
		this.replace_buttons();
		form.submit();
	}
	else {
		top.show_messages('You have not selected any files!');
	}
}


NGS.prototype.check_cuffdiff = function() {
	var query;
	var sams = {};
	var sample = [];
	var dupes;

	var no_gtf = true;
	for (i=1;i<=10;i++) {
		var q = 'query'+i;
		var checkbox = document.cuffdiff_form.elements[q];
		if (checkbox && checkbox.checked) {
			no_gtf = false;
		}
		
	}

	for (i=1;i<=10;i++) {
		for (j=1;j<=4;j++) {
			var sam = 'sam'+i+'_f'+j;
			var select = document.cuffdiff_form.elements[sam];
			if (select) {
				sam_val  = select.value;
				if (sam_val) {
					// just get the base name
					//var sam_html = select.innerHTML;
					//baseName = sam_html.match('/"'+sam_val+'">(\S+)-fx/');
					//alert(sam_val +' '+baseName);
					if (sam_val && sams[sam_val]) {
						dupes = true;
					}
					else {
						sample[i] = 1;
						sams[sam_val] = true;
					}
				}
			}
		}
	}


	if (dupes) {
                var msg = top.warning_message('Error: Duplicate BAM files. Please use each file once only');
		top.show_messages(msg,null,150);
		return false;
        }

	if (sample.length < 3) {
		var msg = top.warning_message('Error: At least two samples are required');
		top.show_messages(msg,null,150);
	        return false;
	}

	if (no_gtf) {
		var msg = top.warning_message('No cufflinks GTF files were selected.<br>\
                The default transcript annotation file will be used');
		top.show_messages(msg,null,150);
      	}

	this.replace_buttons();
	return true;

}

NGS.prototype.check_tophat = function(is_input) {
	var is_fx_trimmed;

	if ( ! is_input && $('tophat_form')) {
	        var q = 'query1';
        	var query1 = $('tophat_form').elements[q];
		if ( query1 ) {
			var query_wrapper = query1.parentNode;
			var fname = query_wrapper.innerHTML;
			is_fx_trimmed = fname.match(/fx\d+/);
		}
	}	

	if ( ! is_fx_trimmed ) {
		var msg = top.warning_message('This FASTQ file has not been quality fiterered/trimmed \
                by the Fastx Toolkit.<br> The quality filtering step is optional.');
		top.show_messages(msg);
	}
	
	this.replace_buttons();
	return true;
}

NGS.prototype.replace_buttons = function() {
	var button_wrapper = $('button_wrapper');
	var processing_div = $('processing');
	if (button_wrapper && processing_div) {
		button_wrapper.toggle();
		processing_div.toggle();
	}
	else {
		this.toggle_buttons();
	}
}

NGS.prototype.toggle_buttons = function() {
	var submit = $('submit');
	var cancel = $('cancel');

	if (submit && cancel) {
        submit.disabled = true;
		cancel.disabled	= true;
	}
}


var ngs;

//Event.observe(top, Prototype.Browser.IE ? 'load' : 'dom:loaded', function() {
Event.observe(window, 'load', function() {
	var step = document.getElementById('step') != null ? parseInt(document.getElementById('step').value, 10) : 0;
	if (console)
		console.info("step = " + step);
	if ($('pid')) {
		ngs = new NGS($('pid').value);
	}
	else {
		ngs = new NGS();
	}
	//alert("step = " + step);
	
	if (step == 1) {
		ngs.enable_status_check();
	}
	/* Step 2 is the add data screen */
	else if (step == 2) {
		if ($('add')) {
			$('add').observe('click', function() {
				ngs.add_data();
			});
		}
	}
	/* Step 3 is TopHat Jobs window */
	else if (step == 3) {
		var jid = document.getElementById('jid').value;
		var tool = document.getElementById('tool').value;
		$('job-' + jid).addClassName('highlight');
		Element.addClassName.delay(0.15, 'job-' + jid, 'fade');
		top.ngs.set_status('ngs_' + tool, 'processing');
		$('step').setValue(0);
	}
	
	/* Step 4 is the Cuffdiff Tables window
	 * If the user made a seletion (Genes or Transcripts, sample selection)
	 * we get that info here and update the drop down menus to reflect their
	 * selections when the page loads
	 */
	else if (step == 4) {
		var s1 = $("selected_sample_one").value;
		var s2 = $("selected_sample_two").value;
		var t = $("selected_type").value;
		if (s1 && s2 && t) {
			$("sample_one").value = s1;
			$("sample_two").value = s2;
			$("genes_or_transcripts").value = t;
		}
		
		Event.observe($("sample_one"), 'change', function() {
			$("sample_one").setStyle({backgroundColor: "white"});
			$("sample_two").setStyle({backgroundColor: "white"});
		});
		Event.observe($("sample_one"), 'change', function() {
			$("sample_one").setStyle({backgroundColor: "white"});
			$("sample_two").setStyle({backgroundColor: "white"});
		});
	}
	
	
	// Add alternating row colors for the Manage Data table using prototype
	// Put this in a step? 
	$$('#manage_data tbody tr:nth-child(even)').each(function(tr) {
		tr.addClassName('even');
	});
	$$('#cuffdiff_jobs #jobs_table tbody tr:nth-child(even)').each(function(tr) {
		tr.addClassName('even');
	});
});



//alert("step = " + Prototype.Browser.IE);
