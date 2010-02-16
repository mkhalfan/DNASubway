//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap', 'trna_scan', 'blastn', 'blastx', 
				'blastn_user', 'blastx_user', 
				'gbrowse', 'apollo', 'exporter', 'target'
				];
var rnames = {
			'repeat_masker' : 'Repeat Masker',
			'trna_scan' : 'tRNA Scan',
			'augustus' : 'Augustus',
			'fgenesh' : 'FgenesH',
			'snap' : 'Snap',
			'blastn' : 'BlastN',
			'blastx' : 'BlastX',
			'blastn_user' : 'User BlastN',
			'blastx_user' :'User BlastX',
			'gbrowse' : 'GBrowse',
			'exporter' : 'Phytozome Browser',
			'target' : 'Phylogenetic Tree'
		};

function check_status (pid, op, h) {
	var b = $(op + '_btn');
	var ind = $(op + '_st');
	/*alert(op + ' - ' + h);
	if (!op || !h)
		return;*/
	var params = { 'pid' : pid, 't' : op, 'h' : h};
	sent = params;
	new Ajax.Request('/project/check_status',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				var file = r.output || '#';
				if (r.running == 0 && r.known == 1) {
					//s.update(' Job waiting in line.');
				}
				else if (r.running == 1 && r.known == 1) {
					//s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));
					//s.addClassName('processing');
					//s.update(' Job running.');
				}
				else if (r.running == 0) {
					clearInterval(intervalID[op]);
					b.removeClassName('processing');
					b.addClassName('done');
					b.onclick = function () { launch(null, file, rnames[op])};
					//b.title = 'Click to view results';
					//b.update('View');

					ind.removeClassName(ind.className);
					ind.addClassName('conIndicator_done');
					//ind.title = 'Done';

					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn');
							var rt_ind = $(routines[i] + '_st');
							
							if (rt_ind && rt_ind.className == 'conIndicator_disabled') {
								//console.log('IND enabling: ' + routines[i] + " // " + rt_ind.className);
								rt_ind.removeClassName('conIndicator_disabled');
								rt_ind.addClassName('conIndicator_not-processed');
								if (i < 7 ) {
									//rt_ind.title = 'Not processed';
								}
								//console.log('IND enabled ' + routines[i]);
							}
							if (rt && rt.className == 'disabled') {
								//console.log('RT enabling.. ' + routines[i]);
								rt.removeClassName('disabled');
								rt.addClassName('not-processed');
								if (i < 7 ) {
									//rt.title = 'Click to process';
									//console.log('RT enabled btn.. ' + this.id);
									rt.onclick = function () {
												var routine = this.id.replace('_btn','');
												run(routine);
											};
								}
								else {
									//console.log('enabling btn.. ' + rt.id);
									rt.onclick = function () {
												//console.log('clicked: ' + routine + ' ' + rnames[routine]);
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
				clearInterval(intervalID[op]);
				b.removeClassName('processing');
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
				clearInterval(intervalID[op]);
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
				clearInterval(intervalID[op]);
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
		b.addClassName('processing');
		//b.title = 'Processing';
	}
	if (ind) {
		ind.removeClassName(ind.className);
		ind.addClassName('conIndicator_processing');
		//ind.title = 'Processing';
	}
	var delay = b ? parseFloat(b.getAttribute('delay')) : 10;
	delay = !isNaN(delay) ? (delay * 1000) : 10000;
	//console.info('delay for ' + op + ' = ' + delay);

	new Ajax.Request('/project/launch_job',{
		method:'get',
		parameters: { 't' : op, pid : p}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
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
}


function launch_apollo() {

	if (!webstartVersionCheck("1.5")) {
		show_messages(
			"Your browser is missing or showing an old version of Java plugin. "
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
			debug(response);
			var r = response.evalJSON();
			if (r.status == 'success') {
				var upl = new Element('iframe', {src: r.file, width: '0px', height:'0px'});
				$('body').insert(upl);
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
}

function close_windows() {
	for (var i = 0; i < windows.length; i++) {
		windows[i].close();
	}
	windows = [];
}

function openWindow(url, title) {
	UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;

	var options = {
		width: 900, 
		height: 496,
		shadow: false,
		draggable: true,
		resizable: true,
		url: url
	};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}

	var w = new UI.URLWindow( options ).center();
	if (title) {
		w.setHeader(title);
	}

	var p = w.getPosition();
	w.setPosition(110, p.left);
	w.show();
	w.focus();
	//windows.push(w);
}

function launch(what, where, title) {
	
	var urls = {
			gbrowse: ['/project/prepare_chadogbrowse?pid=', 'GBrowse'],
			apollo: ['/project/prepare_editor.html?pid=', 'Apollo'],
			exporter: ['/project/prepare_exporter.html?pid=', 'Phytozome Browser'],
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
	if (what && what == 'apollo') {
		launch_apollo();
		return;
	}
	var host = window.location.host;
	var uri = what 
					? 'http://' + host + urls[what][0] + $('pid').value
					: where;
	var window_title = title ? title : urls[what] ? urls[what][1] : null;
	openWindow( uri, title);
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


function show_edit() {
	$('conProjectInfo_edit').update('<div class="bt_projectInfo_done"><a href="javascript:;" onclick="update_info();"></a></div><div class="bt_projectInfo_cancel"><a href="javascript:;" onclick="hide_edit();"></a></div>');
	var ddiv = $('description_container');
	ddiv.setAttribute('origdesc', ddiv.innerHTML);
	var ta = new Element('textarea', {id:'description', style:'width:100%;height: 80px;'});
	ta.value = ddiv.innerHTML;
	ddiv.update(ta);

	var tdiv = $('conProjectInfo_projecttitle');
	tdiv.setAttribute('origtitle', tdiv.innerHTML);

	var ttl = tdiv.innerHTML.replace(/<.+?>.*<\/.+?>/,'');
	ttl = ttl.replace(/^\s+/,'').replace(/\s+$/,'');
	tdiv.update(new Element('input', {id:'title', type:'text',style:'width:300px;', value: ttl, maxlength: 40}));
}

function hide_edit() {
	$('conProjectInfo_edit').update('<div class="bt_projectInfo_edit"><a href="javascript:;" onclick="show_edit();"></a></div>');
	var ddiv = $('description_container');
	ddiv.update( ddiv.readAttribute('origdesc'));
	var tdiv = $('conProjectInfo_projecttitle');
	tdiv.update(tdiv.readAttribute('origtitle'));
}

function update_info() {
	var ttl = $('title');
	var desc = $('description');
	ttl.value = ttl.value.replace(/^\s+/,'').replace(/\s+$/,'');
	desc.value = desc.value.replace(/^\s+/,'').replace(/\s+$/,'');

	if (ttl.value.length > 40) {
		show_errors("Title should have 40 characters or less.");
		//ttl.focus();
		return;
	}
	if (desc.value.length > 140) {
		show_errors("Description should have 140 characters or less.");
		return;
	}
	var params = { pid : $('pid').value, type: 'annotation',
					title : ttl.value, description: desc.value
				};
	//sent = params;
	new Ajax.Request('/project/update', {
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			var r = response.evalJSON();
			if (r.status == 'success') {
				show_messages("Project updated successfully.");
				$('conProjectInfo_projecttitle').writeAttribute('origtitle', ttl.value);
				$('description_container').writeAttribute('origdesc', desc.value);
				hide_edit();
			}
			else  if (r.status == 'error') {
				show_errors("There seems to be an error: " + r.message);
			}
			else {
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
			}
	});
}
//-------------

function set_public(np) {
	if ($('public_yes').disabled)
		return;

	if (np) {
		$('public_yes').checked = true;
		$('public_no').checked = false;
	}
	else {
		$('public_yes').checked = false;
		$('public_no').checked = true;
	}
	
	$('public_yes').disabled = true;
	$('public_no').disabled = true;
	
	// stop hammering the db
	new PeriodicalExecuter(function(p){
				$('public_yes').disabled = false;
				$('public_no').disabled = false;
				p.stop();
		}, 5);
	
	var params = { 'pid' : $('pid').value, 'public' : np, type: 'annotation' };
	sent = params;
	new Ajax.Request('/project/update',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			if (r.status == 'success') {
				show_messages("Project updated successfully.");
			}
			else  if (r.status == 'error') {
				show_errors("There seems to be an error: " + r.message);
			}
			else {
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
			}
	});
}

//-------------
// keep this at the end
Event.observe(window, 'load', function() {
	
	// re-check processing routines' status
	if ($('isowner').value != "1") 
		return;
	
	var as = $$('a');
	for (var i = 0; i < as.length; i++ ) {
	    var stat = as[i].readAttribute('status');
		if (!stat)
			continue;
		if (stat == 'processing') {
			var p = $('pid').value;
			var op = as[i].id.replace('_btn', '');
			var delay = parseInt(as[i].readAttribute('delay'), 10);
			if (isNaN(delay) || delay <= 10) {
				delay = 10;
			}
			intervalID[op] = setInterval(check_status, delay * 1000, p, op, -1);
		}
	}
});
