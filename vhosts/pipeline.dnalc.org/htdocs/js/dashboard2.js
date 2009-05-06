//---

var dbg;

function run (op) {
	var s = $(op);
	var b = $(op + '_btn');
	if (b) b.disable();
	if (s) s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));

	new Ajax.Request('/project/launch_job',{
		method:'get',
		parameters: { 't' : op, pid : $('pid').value}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//alert("Success! \n\n" + response);
			debug(response);
			var r = response.evalJSON();
			dbg = r;
			//alert(r);
			if (r.status == 'success') {
				var file = r.file || '#';
				s.update(
					new Element('a', {href: file, target: '_blank'}).update('View output')
				);
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

