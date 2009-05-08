//---

var dbg;
var intervalID = {};

function check_status (pid, op, h) {
	var s = $(op);
	s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));

	new Ajax.Request('/project/check_status',{
		method:'get',
		parameters: { 'pid' : pid, 't' : op, 'h' : h}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				var file = r.output || '#';
				if (r.running == 0 && r.known == 1) {
					s.update('Job waiting in line.');
				}
				else if (r.running == 1 && r.known == 1) {
					s.update('Job running.');
				}
				else if (r.running == 0) {
					clearInterval(intervalID[op]);
					s.update('Job done. ');
					s.appendChild(new Element('a', {'href' : file,'target':'_blank'}).update('View file'));
				} else {}
			}
			else  if (r.status == 'error') {
				clearInterval(intervalID[op]);
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
	if (s) s.update('Job sent');

	new Ajax.Request('/project/launch_job',{
		method:'get',
		parameters: { 't' : op, pid : p}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				var h = r.h || '';
				var delay = parseFloat(s.getAttribute('delay'));
				delay = !isNaN(delay) ? delay * 1000 : 5000;
				intervalID[op] = setInterval(check_status, delay, p, op, h);
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


