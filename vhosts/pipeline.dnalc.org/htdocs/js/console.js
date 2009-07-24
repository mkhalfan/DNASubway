//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap', 'blastn', 'blastx', 
				'blastn_user', 'blastx_user', 
				'gbrowse', 'apollo', 'exporter'];
var windows = [];

function check_status (pid, op, h) {
	var b = $(op + '_btn');

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
					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn');
							if (rt && rt.className == 'disabled') {
								//console.log('enabling.. ' + routines[i]);
								rt.removeClassName('disabled');
								rt.addClassName('not-processed');
								//Event.observe(routines[i], 'click', function() {
								if (i < 5 ) {
									rt.title = 'Click to process';
									rt.onclick = function () {
												//console.log('enable btn.. ' + this.id);
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
					}
				} else {}
			}
			else  if (r.status == 'error') {
				clearInterval(intervalID[op]);
				b.removeClassName('processing');
				b.addClassName('error');
				b.title = 'Click to try again';
				b.onclick = function () {
								run(op);
							};


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
	b.onclick = null;
	if (b) {
		b.removeClassName(b.className);
		b.addClassName('processing');
		b.title = 'Processing';
	}
	var delay = b ? parseFloat(b.getAttribute('delay')) : 5;
	delay = !isNaN(delay) ? delay * 1000 : 5000;

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
	//alert(abtn.getAttribute('commonname'));
	var status_div = $('apollo_status');
	status_div.show();

	var sel = abtn.getAttribute('commonname') + ':1..' + abtn.getAttribute('seq_length');
	var params = { 'selection' : sel};
	sent = params;
	new Ajax.Request('/cgi-bin/create-jnpl.pl',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				status_div.update(
					new Element('a', {'href' : r.file}).update('Open Apollo.')
				);
				var upl = new Element('iframe', {src:'/project/upload.html', width: '100%', height:'50px'});
				status_div.appendChild(upl);
			}
			else  if (r.status == 'error') {
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
		width: 916, 
		height: 496,
		shadow: true,
		draggable: false,
		resizable: false,
		url: url
	};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}

	var w = new UI.URLWindow( options ).center();

	var p = w.getPosition();
	w.setPosition(78, p.left-2);
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

	if (what && !urls[what]) {
		alert('Nothing to load!!');
		return;
	}
	/*if (what && what == 'apollo') {
		launch_apollo();
		return;
	}*/
	var host = window.location.host;
	var uri = what 
					? 'http://' + host + urls[what] + $('pid').value
					: where;
	//alert(uri);
	openWindow( uri );
}

function debug(msg) {
	var d = $('debug');
	if (d) d.update(msg);
}

//-------------
// keep this at the end
Event.observe(window, 'load', function() {
	var as = $$('a');
	var x = 0;
	for (var i = 0; i < as.length; i++ ) {
	    var stat = as[i].readAttribute('status');
		if (!stat)
			continue;
		if (stat == 'processing') {
			var p = $('pid').value;
			var op = as[i].id.replace('_btn', '');
			intervalID[op] = setInterval(check_status, 10000, p, op, -1);
		}
	}
});
