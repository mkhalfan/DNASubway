//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap', 'trna_scan', 'blastn', 'blastx', 
				'blastn_user', 'blastx_user', 
				'gbrowse', 'apollo', 'exporter', 'target'
				];
var rnames = {
			'repeat_masker' : 'RepeatMasker',
			'trna_scan' : 'tRNA Scan',
			'augustus' : 'Augustus',
			'fgenesh' : 'FgenesH',
			'snap' : 'SNAP',
			'blastn' : 'BLASTN',
			'blastx' : 'BLASTX',
			'blastn_user' : 'User BLASTN',
			'blastx_user' :'User BLASTX',
			'gbrowse' : 'GBrowse',
			'exporter' : 'External Browser',
			'target' : 'Phylogenetic Tree'
		};

function check_status (pid, op, h) {
	var b = $(op + '_btn');
	var ind = $(op + '_st');
	/*alert(op + ' - ' + h);*/
	if (!op || !h)
		return;
	var params = { 'pid' : pid, 't' : op, 'h' : h};
	sent = params;

	new Ajax.Request('/project/check_status',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(op + ': ' + response);
			var r = response.evalJSON();
			//dbg = r;
			if (r.status == 'success') {
				var file = r.output || '#';

				if (r.running == 0 && !r.known) {
					//b.removeClassName('processing');
					b.removeClassName('disabled');
					b.addClassName('done');
					//b.onclick = function () { launch(null, file, rnames[op])};
					b.onclick = function () { launch(null, "/project/gff_to_html?f=" + file, rnames[op])};

					ind.removeClassName(ind.className);
					ind.addClassName('conIndicator_done');
					window.clearInterval(intervalID[op]);
					//debug(op + ": - just stoped it!");

					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn');
							var rt_ind = $(routines[i] + '_st');
							
							// some routines may be disabled
							if (rt_ind && rt_ind.hasAttribute('rdisabled')) {
								continue;
							}
							
							if (rt_ind && rt_ind.className == 'conIndicator_disabled') {
								rt_ind.removeClassName('conIndicator_disabled');
								rt_ind.addClassName('conIndicator_not-processed');
								if (i < 7 ) {
									//rt_ind.title = 'Not processed';
								}
							}
							if (rt && rt.className == 'disabled') {
								rt.removeClassName('disabled');
								rt.addClassName('not-processed');
								if (i < 7 ) {
									rt.onclick = function () {
												var routine = this.id.replace('_btn','');
												run(routine);
											};
								}
								else {
									rt.onclick = function () {
												var routine = this.id.replace('_btn','');
												launch(routine, null, rnames[routine]);
											};
								}
							}
						}
						if ($('isowner').value == "1") {
							$('apollo_btn').onclick = function () { launch('apollo'); };
							$('apollo_btn').removeClassName('disabled');
							$('apollo_ind').removeClassName("conIndicator_disabled");
							$('apollo_ind').addClassName("conIndicator_not-processed");
							$('evidence_ind').removeClassName('conIndicator_disabled');
							$('evidence_ind').addClassName('conIndicator_not-processed');
							$('add_evidence_link').removeClassName('disabled');
							$('add_evidence_link').onclick = function () {
									$('add_evidence').style.visibility='visible';
									$('add_evidence').style.display='block';
									$('add_evidence_link').hide();
								};
						}
						$('gbrowse_btn').onclick = function () { launch('gbrowse', null, rnames['gbrowse']); };
						$('gbrowse_btn').removeClassName('disabled');
						$('gbrowse_ind').removeClassName("conIndicator_Rb_disabled");
						$('gbrowse_ind').addClassName("conIndicator_Rb");
						if ($('exporter_btn')) {
							$('exporter_btn').onclick = function () { launch('exporter', null, rnames['exporter']); };
							$('exporter_btn').removeClassName('disabled');
							$('exporter_ind').removeClassName("conIndicator_Rb_disabled");
							$('exporter_ind').addClassName("conIndicator_Rb");
						}
						$('target_btn').onclick = function () { launch('target', null, rnames['target']); };
						$('target_btn').removeClassName('disabled');
						$('target_ind').removeClassName("conIndicator_Rb_disabled");
						$('target_ind').addClassName("conIndicator_Rb");
					}
				} else {}
			}
			else  if (r.status == 'error') {
				window.clearInterval(intervalID[op]);
				//b.removeClassName('processing');
				b.removeClassName('disabled');
				b.addClassName('error');
				//b.title = 'Click to try again';
				b.onclick = function () {
								run(op);
							};
				ind.removeClassName(ind.className);
				ind.addClassName('conIndicator_error');
				//ind.title = 'Error';
			}
			else {
				//s.update('Unknown status!');
				alert('Unknown status!');
				window.clearInterval(intervalID[op]);
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
				window.clearInterval(intervalID[op]);
			}
	});

}

function run (op) {
	//var s = $(op);
	var b = $(op + '_btn');
	var p = $('pid').value;
	var ind = $(op + '_st');

	if (b) {
		b.onclick = null;
		b.removeClassName(b.className);
		//b.addClassName('processing');
		b.addClassName('disabled');
		//b.title = 'Processing';
	}
	if (ind) {
		ind.removeClassName(ind.className);
		ind.addClassName('conIndicator_processing');
		//ind.title = 'Processing';
	}
	var delay = b ? parseFloat(b.getAttribute('delay')) : 10;
	delay = !isNaN(delay) ? (delay * 1000) : 10000;

	new Ajax.Request('/project/launch_job',{
		method:'get',
		parameters: { 't' : op, pid : p}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(response);
			var r = response.evalJSON();
			//dbg = r;
			//alert('after launch job:\n' + response + ' ' + r.h);
			if (r.status == 'success') {
				var h = r.h || '';
				intervalID[op] = setInterval(function (){ check_status(p, op, h)}, delay);
				if (op == 'fgenesh') {
					var tout = 5;
					if (r.warning) {
						var fwarn = $('fgenesh_warning');
						if (!fwarn) {
							fwarn = new Element('div', {id:'fgenesh_warning'});
							$('conMessage_FgenesH').insert(fwarn);
						}
						fwarn.update(r.warning);
						tout = 15;
					}
					$('conMessage_FgenesH').style.display = 'block';
					new PeriodicalExecuter(function(p){
							$('conMessage_FgenesH').style.display = 'none';
							p.stop();
						}, tout);
				}
			}
			else  if (r.status == 'error') {
				b.removeClassName(b.className);
				b.addClassName('error');
				
				ind.removeClassName(ind.className);
				ind.addClassName('conIndicator_error');
				//ind.title = 'Error';
				
				show_errors(r.message);
			}
			else {
				//s.update('Unknown status!');
				//alert('Unknown status!');
			}
		},
		onFailure: function(){
				alert('Something went wrong!\nAborting...');
			}
	});
	
	try {
		pageTracker._trackEvent(rnames[op] || op, "run");
	} catch (e) {
		debug(e.toString());
	};
}


function launch_apollo() {

	if (!deployJava.isWebStartInstalled("1.6+")) {
		show_messages(
			"Your browser is missing (or showing an old version of) Java plugin. "
			+ "Please <a href=\""
			+ "http://jdl.sun.com/webapps/getjava/BrowserRedirect?locale=en&host=java.com\">"
			+ "install latest Java</a> to launch Apollo.");
		return;
	}

	var abtn = $('apollo_btn');	
	if (abtn.getAttribute("working") == 1 ) {
		return;
	}
	abtn.setAttribute("working", 1);
	/*var i = 0;
	var pe = new PeriodicalExecuter(function(p){
		i++;
		var suffix = '';
		for (var x = 0; x < i%4; x++)
			suffix +=".";
			abtn.update("Apollo<strong>" + suffix + "</strong>");
		},
		.4
	);*/
	$('apollo_ind').removeClassName("conIndicator_not-processed");
	$('apollo_ind').addClassName("conIndicator_processing");

	var params = { 'pid' : $('pid').value };
	sent = params;
	new Ajax.Request('/project/dump_game_file',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(response);
			var r = response.evalJSON();
			if (r.status == 'success') {
				//var upl = new Element('iframe', {src: r.file, width: '0px', height:'0px'});
				//$('body').insert(upl);
				deployJava.launch(r.file);
			}
			else  if (r.status == 'error') {
				alert("There seems to be an error: " + r.message);
			}
			else {
			}
			//pe.stop();
			//abtn.update("Apollo");
			abtn.setAttribute("working", 0);
			$('apollo_ind').removeClassName("conIndicator_processing");
			$('apollo_ind').addClassName("conIndicator_not-processed");
		},
		onFailure: function(){
				//pe.stop();
				//abtn.update("Apollo");
				$('apollo_ind').removeClassName("conIndicator_processing");
				$('apollo_ind').addClassName("conIndicator_not-processed");
				alert("Something went wrong.");
				abtn.setAttribute("working", 0);
			}
	});
	
	try {
		pageTracker._trackEvent("Apollo", "view");
	} catch (e) {
		debug(e.toString());
	};
}

function close_windows() {
	for (var i = 0; i < windows.length; i++) {
		windows[i].close();
	}
	windows = [];
}

function launch(what, where, title) {
	
	var urls = {
			gbrowse: ['/project/prepare_chadogbrowse?pid=', 'GBrowse'],
			apollo: ['/project/prepare_exporter.html?apollo=1;pid=', 'Apollo'],
			exporter: ['/project/prepare_exporter.html?pid=', 'External Browser'],
			target: ['/project/prepare_chadogbrowse?warn=1;pid=', 'Phylogenetic Tree']
		};

	try {
		$('add_evidence').hide();
		$('add_evidence_link').show();
	}
	catch (e) {
		//
	}

	if (what && !urls[what]) {
		alert('Nothing to load!!');
		return;
	}
/*	if (what && what == 'apollo') {
		launch_apollo();
		return;
	}
*/
	var host = window.location.host;
	var uri = what 
					? 'http://' + host + urls[what][0] + $('pid').value
					: where;
	var window_title = title ? title : urls[what] ? urls[what][1] : null;
	openWindow( uri, title);
	
	try {
		pageTracker._trackEvent(title, "view");
	} catch (e) {
		debug(e.toString());
	};
}

function createTargetPoject(sel) {

	//close_windows();
	var m = sel.match(/(\w+_\d+):(\d+)\.\.(\d+)/);
	if (!m || m.length != 4) {
		alert('Invalid selection.');
		return;
	}

	var start = parseInt(m[2], 10);
	var stop = parseInt(m[3], 10);
	if (isNaN(start) || isNaN(stop) ) {
		alert("Invalid selection!");
		return;
	}

	if (!m || m.length != 4) {
		alert('stop <= start');
		return;
	}
	if ( stop - start > 10000 ) {
		alert("Selection too large! Select maximum 10000 bp.");
		return;
	}

	top.document.location.href = '/project/target/create/' + m[1] + '/' + m[2] + '/' +  m[3];
}

function debug(msg) {
	try {
		var d = $('debug');
		if (d) d.update(msg);
		if (console) console.info(msg);
	}
	catch (e) {
		;
	}
}

//-------------
// keep this at the end
Event.observe(window, isMSIE ? 'load' : 'dom:loaded', function() {
	
	// re-check processing routines' status
	if ($('isowner').value != "1") 
		return;
	
	var pid = $('pid').value;
	var as = $$('a');
	for (var i = 0; i < as.length; i++ ) {
	    var stat = as[i].readAttribute('status');
		if (!stat)
			continue;
		if (stat == 'processing') {
			
			var op = as[i].id.replace('_btn', '');
			var delay = parseInt(as[i].readAttribute('delay'), 10);
			if (isNaN(delay) || delay <= 10) {
				delay = 10;
			}
			
			if (isMSIE) {
				var callback = "check_status(" + pid + ", '" + op + "', -1)";
				//debug(callback);
				intervalID[op] = setInterval(callback, 20000);
			}
			else {
				intervalID[op] = setInterval(check_status, delay * 1000, pid, op, -1);
			}

			//debug(" ** " + op + " : interval_id = " + intervalID[op]);
		}
	}
});
