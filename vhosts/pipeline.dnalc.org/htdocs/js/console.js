//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap', 'blastn', 'blastx'];

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
					//s.update('Job done. ');
					b.href = file;
					b.target = '_blank';
					//s.appendChild(new Element('a', {'href' : file,'target':'_blank'}).update('View file'));
					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn');
							if (rt && rt.className == 'disabled') {
								console.log('enabling.. ' + routines[i]);
								rt.removeClassName('disabled');
								rt.addClassName('not-processed');
								//Event.observe(routines[i], 'click', function() {
								rt.onclick = function () {
												console.log('enable btn.. ' + this.id);
												var routine = this.id.replace('_btn','');
												run(routine);
											};
							}
						}
					}
				} else {}
			}
			else  if (r.status == 'error') {
				clearInterval(intervalID[op]);
				b.removeClassName('processing');
				b.addClassName('error');
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
		//s.update('Job sent.');
		//s.insert(' Job sent.');
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
