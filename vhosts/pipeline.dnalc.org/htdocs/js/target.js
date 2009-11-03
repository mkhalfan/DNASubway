var dbg;
var intervalID = 0;

function launch_target () {
	var inputs = $$('input');
	var genomes = [];

	inputs.each(function(item) {
	  if (item.type == 'checkbox' && item.id.substr(0,2) == 'g_' && item.checked)
		genomes.push(item.id.replace(/^g_/, ''));
	});
	if (genomes.length == 0) {
		alert("You must pick at least one genome.");
		return;
	}
	
	if ($('tstatus').value == 'done') {
		if (!confirm("You are about to remove the results of your search.\n"
						+ "Are you sure you want to continue?"))
			return;
	}
	
	$('launch_btn').hide();
	$('alignment_span').update('<a href="#">Multiple<br/>Alignment</a>');
	$('tree_btn').onclick = null;
	$('tree_btn').stopObserving ('click');

	var tid = $('tid') ? $('tid').value : 0;
	var params = { 'tid' : tid, 'g' : genomes};
	//sent = params;
	new Ajax.Request('/project/target/launch_job',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(response);
			var r = response.evalJSON();
			dbg = r;
			if (r.status == 'success') {
				var h = r.h || '';
				intervalID = setInterval(function (){ check_status(tid, h)}, 10000);
				$('message').update("processing");
			}
			else  if (r.status == 'error') {
				alert(r.message);
				$('launch_btn').show();
			}
			else {
				alert('Unknown status!');
			}
			//$('launch_btn').show();
		},
		onFailure: function(){
				alert("Something went wrong.");
				clearInterval(intervalID);
				$('launch_btn').show();
		}
	});
}


function check_status (tid, h) {
	var params = { 'tid' : tid, 'h' : h};
	sent = params;
	new Ajax.Request('/project/target/check_status',{
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(response);
			var r = response.evalJSON();
			dbg = r;
			//console.info(r.status);
			if (r.status != "processing") {
				clearInterval(intervalID);
				//console.info("clearing id = " + intervalID);
				if (r.status == 'done') {
					$('message').update("Done");
					if (r.files && r.files['fasta']) {
						var abtn = $('alignment_span');
						abtn.update('<applet archive="/files/jalview/jalviewApplet.jar" name="Jalview_muscle_1" code="jalview.bin.JalviewLite" height="35" width="110">'
							+ '<param name="file" value="' + r.files['fasta'] + '">'
							+ '<param name="showAnnotation" value="true">'
							+ '<param name="windowHeight" value="500">'
							+ '<param name="windowWidth" value="650">'
							+ '<param name="showFullId" value="false">'
							+ '<param name="label" value="View Alignment">'
							+ '<param name="defaultColour" value="Clustal">'
							+ '</applet>'
						);
					}
					if (r.files && r.files['nw']) {
						var start = top.document.location.href.indexOf('.org')
						var server = top.document.location.href.substr(0,start +4);
						$('tree_btn').observe('click', function() {
							
							window.open('/files/phylowidget/bare.html?tree=' + server + r.files['nw'], 'target_tree', 'status=0,height=500,width=600');
						});
					}
				}
				else if (r.status == "done-empty") {
					$('message').update("No homologs found. Try searching other genomes.");
				}
				else if (r.status == "failed") {
					$('message').update("Failed to get the results from Target.");
				}
				$('launch_btn').show();
			}
			else {
				//console.info("status = " + r.status);
				//$('launch_btn').show();
			}
			//alert(r.status);
		},
		onFailure: function(){
				s.update("Something went wrong.");
				clearInterval(intervalID);
			}
	});
}


function launch_tree(nw) {
	if (!nw)
		return;

	UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;

	function openWindow(url) {
		new UI.URLWindow({
			width: 700, 
			height: 600,
			shadow: true,
			url: url 
		}).show();  
	}

	openWindow("/files/phylowidget/bare.html?tree=" +  nw);
}


function launch_viewseq(tid) {
	if (!tid)
		return;

	UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;

	function openWindow(url) {
		new UI.URLWindow({
			width: 1000, 
			height: 600,
			shadow: true,
			url: url 
		}).center().show();
	}

	openWindow("/project/target/view_seq/" +  tid);
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
	if ($('tid')) {
		var tid = $('tid').value;
		var spans = $$('span');
		var btn = $('launch_btn');
		if (btn && btn.style.display == 'none') {
				intervalID = setInterval(check_status, 10000, tid, -1);
		}
	}
});


