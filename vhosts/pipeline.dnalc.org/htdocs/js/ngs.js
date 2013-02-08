


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

		var b = $(op + '_btn');
		var ind = $(op + '_st');

		ind.removeClassName(ind.className);

		b.onclick = function(){ ngs.launch(op); };
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
			data: ['/project/ngs/tools/manage_data?pid=', 'Manage data'],
			ngs_cufflinks: ['/project/ngs/tools/tool_job_list?tool=' + tool + '&pid=', 'Cufflinks'],
			ngs_cuffdiff: ['/project/ngs/tools/tool_job_list?tool=' + tool + '&pid=', 'Cuffdiff'],
			ngs_tophat: ['/project/ngs/tools/job_list_' + tool + '?pid=' , 'TopHat'],
			ngs_fxtrimmer: ['/project/ngs/tools/tool_job_list?tool=' + tool + '&pid=' , 'FastX Toolkit'],
			ngs_cuffmerge: ['/project/ngs/tools/tool_job_list?tool=' + tool + '&pid=' , 'Cuffmerge']
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
	if (ngs.status_check_enabled != null)
		return;
	var pe = new PeriodicalExecuter(function(pe) {
			ngs.check_status();
		}, 30);
	ngs.status_check_enabled = pe;
};

NGS.prototype.disable_status_check = function() {
	if (ngs.status_check_enabled != null)
		ngs.status_check_enabled.stop();
};

NGS.prototype.check_status = function() {
	new Ajax.Request('/project/ngs/tools/tool_stats', {
		method:'get',	
		parameters: {'pid': this.pid},
		onSuccess: function(transport){
				var r = transport.responseText.evalJSON();
				if (r && r.status == 'success') {
					var processing = 0;
					$H(r.tools).keys().each(function(t) {
						//if (t != 'ngs_fastqc' && t != 'ngs_fxtrimmer') {
						if (t != 'ngs_fastqc') {
							//console.info(t + ' ' + ngs.get_status(t) + ' ' + r.tools[t]);
							if (ngs.get_status(t) != r.tools[t]) {
								console.info('  ++ =>' + t);
								ngs.set_status(t, r.tools[t]);
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

NGS.prototype.basic_run = function(tool, pid, fid, a) {
	cell = a.up();
	cell.update('<img src="/images/ajax-loader-2.gif" style="width:12px;padding-left:5px;" class="alpha">');
	new Ajax.Request('/project/ngs/tools/app_' + tool, {
		method:'post',	
		parameters: {'pid': pid, 'query1': fid, 'basic_run': 1},
		onSuccess: function(transport){
				var r = transport.responseText.evalJSON();
				if (r && r.status == 'success') {
					// Default last row is the file row
					lastRow = $('file' + fid);
					// Get the last row in the current files' jobs listing
					childRows = $$('[parent="file' + fid + '"]');
					// If there are child rows, update last row to be 
					// the last row of the child jobs of this file
					if (childRows.length > 0) {
						lastRow = childRows[childRows.length - 1];
					}
					// Add a processing icon only if the job status is 'processing'
					processing_icon = "";
					if (r.job_status == 'processing') {
						processing_icon = ' <img src="/images/ajax-loader-2.gif" width="12px;">';
					}
					lastRow.insert({after:'<tr id="job-' + r.job_id + '" class="highlight" parent="file' + fid + '"><td></td><td>' + r.job_name + '</td><td></td><td></td><td>' + r.job_status + processing_icon + '</td><td></td></tr>'});
					Element.addClassName.delay(0.15, 'job-' + r.job_id, 'fade');
					cell.update('<span class="disabled_text_submit">Run</span>');
				}
				else {
					console.warn("Error: " + r.message);
					cell.upadte('<a onclick="javascript:ngs.basic_run("tophat", ' + pid + ', ' + fid + ', this)" href="javascript:;" class="text_submit">Run</a>');
				}
			},
		onFailure: function(){ 
			alert('Something went wrong!\nAborting...');
			cell.upadte('<a onclick="javascript:ngs.basic_run("tophat", ' + pid + ', ' + fid + ', this)" href="javascript:;" class="text_submit">Run</a>');
		}
	});
};

NGS.prototype.toggle_params = function(){
	$('app_parameters').toggle();
	$('show_params').toggle();
	$('hide_params').toggle();
}

var ngs, window;

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
		$('job-' + jid).addClassName('highlight');
		Element.addClassName.delay(0.15, 'job-' + jid, 'fade');
	}
	
	
	//Add alternating row colors for tables using prototype
	//$$('#jobs_table tbody tr:nth-child(even)').each(function(tr) {
		//tr.addClassName('even');
	//});
});

//alert("step = " + Prototype.Browser.IE);
