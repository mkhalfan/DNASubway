//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap', 'blastn', 'blastx', 
				'blastn_user', 'blastx_user', 
				'gbrowse', 'apollo', 'exporter'];
var windows = [];

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
					b.onclick = function () { launch(null, file)};
					b.title = 'Click to view results';
					//b.update('View');

					ind.removeClassName(ind.className);
					ind.addClassName('conIndicator_done');
					ind.title = 'Done';

					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn');
							var rt_ind = $(routines[i] + '_st');
							
							if (rt_ind && rt_ind.className == 'conIndicator_disabled') {
								//console.log('IND enabling: ' + routines[i] + " // " + rt_ind.className);
								rt_ind.removeClassName('conIndicator_disabled');
								rt_ind.addClassName('conIndicator_not-processed');
								if (i < 7 ) {
									rt_ind.title = 'Not processed';
								}
								//console.log('IND enabled ' + routines[i]);
							}
							if (rt && rt.className == 'disabled') {
								//console.log('RT enabling.. ' + routines[i]);
								rt.removeClassName('disabled');
								rt.addClassName('not-processed');
								if (i < 7 ) {
									rt.title = 'Click to process';
									//rt.update('Run');
									//console.log('RT enabled btn.. ' + this.id);
									rt.onclick = function () {
												var routine = this.id.replace('_btn','');
												run(routine);
											};
								}
								else {
									rt.onclick = function () {
												//console.log('enable btn.. ' + this.id);
												var routine = this.id.replace('_btn','');
												launch(routine);
											};
								}
							}
						}
						$('apollo_btn').onclick = function () { launch('apollo'); };
						$('gbrowse_btn').onclick = function () { launch('gbrowse'); };
						if ($('exporter_btn')) {
							$('exporter_btn').onclick = function () { launch('exporter'); };
						}
					}
				} else {}
			}
			else  if (r.status == 'error') {
				clearInterval(intervalID[op]);
				b.removeClassName('processing');
				b.addClassName('error');
				b.title = 'Click to try again';
				//b.update('Failed/Run');
				b.onclick = function () {
								run(op);
							};
				ind.removeClassName(ind.className);
				ind.addClassName('conIndicator_error');
				ind.title = 'Error';
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
		b.title = 'Processing';
		//b.update('Processing');
	}
	if (ind) {
		ind.removeClassName(ind.className);
		ind.addClassName('conIndicator_processing');
		ind.title = 'Processing';
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
			}
			else  if (r.status == 'error') {
				b.removeClassName(b.className);
				b.addClassName('error');
				
				ind.removeClassName(ind.className);
				ind.addClassName('conIndicator_error');
				ind.title = 'Error';
				
				show_errors(r.message);
			}
			else {
				//s.update('Unknown status!');
				//alert('Unknown status!');
			}
		},
		onFailure: function(){
				//s.update("Something went wrong.");
				alert('Something went wrong!\nAborting...');
			}
	});
}


function launch_apollo() {
	var abtn = $('apollo_btn');
	abtn.parentNode.hide();
	//alert(abtn.getAttribute('commonname'));
	var status_div = $('apollo_status');
	status_div.show();

	var params = { 'pid' : $('pid').value };
	sent = params;
	new Ajax.Request('/project/dump_game_file',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				var a = new Element('a', {'href' : r.file, id: 'launch_a'}).update('Launch Apollo');
				status_div.update( a );
				//a.fire('click');
				var upl = new Element('iframe', {src: r.file, width: '0px', height:'0px', style: 'display: none'});
				status_div.appendChild(upl);
			}
			else  if (r.status == 'error') {
				alert("There seem to be an error: " + r.message);
			}
			else {
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
			}
	});
}

function close_windows() {
	for (var i = 0; i < windows.length; i++) {
		windows[i].close();
	}
	windows = [];
	toggle_console_link();
}

function toggle_console_link() {

	return;

	var d = $('backtoconsole_head');
	d.update();
	if (windows.length) {
		var a = new Element('a', {href:'javascript:;'}).update('CONSOLE');
		a.style.color = 'black';
		Event.observe(a, 'click', function(){close_windows()});
		//Event.observe(a, 'mouseover', function(){this.style.color});
		d.appendChild(a);
	}
	else {
		d.update('CONSOLE');
	}
}


function openWindow(url) {
	UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;

	var options = {
		width: 1024, 
		height: 496,
		shadow: true,
		draggable: false,
		resizable: true,
		url: url
	};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}

	var w = new UI.URLWindow( options ).center();

	var p = w.getPosition();
	w.setPosition(110, p.left);
	w.show();
	w.focus();
	windows.push(w);
	toggle_console_link();
}

function launch(what, where) {
	
	var urls = {
			gbrowse: '/project/prepare_chadogbrowse?pid=',
			apollo: '/project/prepare_editor.html?pid=',
			exporter: '/project/prepare_exporter.html?pid='
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
					? 'http://' + host + urls[what] + $('pid').value
					: where;
	//alert(uri);
	openWindow( uri );
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
		alert("Error!");
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
	var d = $('debug');
	if (d) d.update(msg);
}


function show_errors(html) {

	if (!html || !UI) {
		return;
	}
	var resizable = true;
	var options = {	
			resizable: false,
        	width: 400,
	        height: 200,
	        shadow: true,
	        draggable: false
		};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}
	var w = new UI.Window(options).center();
	html = "<div class=\"conNewPro_title\" style=\"vertical-align: middle; padding: 20px\">" + html + "</div>";
	w.setContent(html);
	w.show(true);

}

//-------------
// keep this at the end
Event.observe(window, 'load', function() {
	// check for errors
	var err = $("error_list");
	if (err) {
		var html = err.innerHTML;
		if (html) {
			show_errors(html);
		}
	}
	
	// re-check processing routines' status
	var as = $$('a');
	var x = 0;
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
