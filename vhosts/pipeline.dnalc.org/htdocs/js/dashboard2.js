//---

var dbg, sent;
var intervalID = {};
var routines = ['augustus', 'fgenesh', 'snap'];

function check_status (pid, op, h) {
	var s = $(op);

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
					/*s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));*/
					s.update(' Job waiting in line.');
				}
				else if (r.running == 1 && r.known == 1) {
					//s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));
					//s.addClassName('processing');
					s.update(' Job running.');
				}
				else if (r.running == 0) {
					clearInterval(intervalID[op]);
					s.removeClassName('processing');
					s.update('Job done. ');
					s.appendChild(new Element('a', {'href' : file,'target':'_blank'}).update('View file'));
					if (op == 'repeat_masker') {
						for (var i = 0; i < routines.length; i++) {
							var rt = $(routines[i] + '_btn')
							if (rt) rt.enable();
						}
					}
				} else {}
			}
			else  if (r.status == 'error') {
				clearInterval(intervalID[op]);
				s.removeClassName('processing');
				s.addClassName('error');
				s.update('Error');

				var b = $(op + '_btn');
				if (b) b.enable();
			}
			else {
				s.update('Unknown status!');
				clearInterval(intervalID[op]);
			}
		},
		onFailure: function(){
				s.update("Something went wrong.");
				clearInterval(intervalID[op]);
			}
	});

}

function run (op) {
	var s = $(op);
	var b = $(op + '_btn');
	var p = $('pid').value;
	if (b) b.disable();
	if (s) {
		s.removeClassName('error');
		s.addClassName('processing');
		s.update('Job sent.');
		//s.insert(' Job sent.');
	}

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
				var delay = parseFloat(s.getAttribute('delay'));
				delay = !isNaN(delay) ? delay * 1000 : 5000;
				/*alert('about to check again:\n' +
					'delay = ' + delay + '\n' +
					'p = ' + p + '\n' +
					'op = ' + op + '\n' +
					'h = ' + h );*/
				intervalID[op] = setInterval(function (){ check_status(p, op, h)}, delay);
			}
			else  if (r.status == 'error') {
				s.update(r.error);
			}
			else {
				s.update('Unknown status!');
			}
		},
		onFailure: function(){
				s.update("Something went wrong.");
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
	var spans = $$('span');
	var x = 0;
	for (var i = 0; i < spans.length; i++ ) {
	    var stat = spans[i].readAttribute('status');
		if (!stat)
			continue;
		if (stat == 'Processing') {
			var p = $('pid').value;
			var op = spans[i].id;
			intervalID[op] = setInterval(check_status, 10000, p, op, -1);
		}
	}
});
