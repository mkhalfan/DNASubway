var dbg;
var intervalID = 0;

function launch_target () {
	var inputs = $$('input');
	var genomes = [];
	
	var btn_ind = $('launch_btn_ind');
	if (btn_ind.hasClassName('conIndicator_processing')) {
		//alert('');
		//console.info('already processing');
		return;
	}

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
	
	$('message').update("");
	//$('message').update("Processing.");
	/*$('launch_btn').hide();*/
	
	/*$('alignment_span').update('<a href="#">Multiple<br/>Alignment</a>');
	$('tree_btn').onclick = null;
	$('tree_btn').stopObserving ('click');*/
	
	btn_ind.removeClassName('conIndicator_not-processed');
	btn_ind.removeClassName('conIndicator_error');
	btn_ind.addClassName('conIndicator_processing');

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
				intervalID = setInterval(function (){ check_status(tid, h)}, 15000);
				$('alignment_span').update('<a href="#">Alignment<br/>Viewer</a>');
				$('tree_btn').onclick = null;
				$('tree_btn').stopObserving ('click');
				
				var alignment_ind = $('alignment_ind');
				alignment_ind.removeClassName('conIndicator_Rb');
				alignment_ind.addClassName('conIndicator_Rb_disabled');
				var tree_ind = $('tree_ind');
				tree_ind.removeClassName('conIndicator_Rb');
				tree_ind.addClassName('conIndicator_Rb_disabled');
				
			}
			else  if (r.status == 'error') {
				$('message').update('');
				alert(r.message);
				//$('launch_btn').show();
				btn_ind.removeClassName('conIndicator_processing');
				btn_ind.addClassName('conIndicator_error');
			}
			else {
				alert('Unknown status!');
				//btn_ind.addClassName('conIndicator_not-processed');
			}
			//$('launch_btn').show();
		},
		onFailure: function(){
				alert("Something went wrong.");
				clearInterval(intervalID);
				//$('launch_btn').show();
		}
	});
}


function check_status (tid, h) {
	var btn_ind = $('launch_btn_ind');
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
				btn_ind.removeClassName('conIndicator_processing');
				if (r.status == 'done') {
					//$('message').update("Done. Check results.");
					if (r.files && r.files['fasta']) {
						var abtn = $('alignment_span');
						abtn.update('<applet archive="/files/jalview/jalviewApplet.jar" name="Jalview_muscle_1" code="jalview.bin.JalviewLite" height="35" width="110">'
							+ '<param name="file" value="' + r.files['fasta'] + '">'
							+ '<param name="showAnnotation" value="true">'
							+ '<param name="windowHeight" value="500">'
							+ '<param name="windowWidth" value="650">'
							+ '<param name="showFullId" value="false">'
							+ '<param name="label" value="Alignment Viewer">'
							+ '<param name="defaultColour" value="Clustal">'
							+ '</applet>'
						);
						var abtn_ind = $('alignment_ind');
						abtn_ind.removeClassName('conIndicator_Rb_disabled');
						abtn_ind.addClassName('conIndicator_Rb');
					}
					if (r.files && r.files['nw']) {
						//var start = top.document.location.href.indexOf('.org')
						//var server = top.document.location.href.substr(0,start +4);
						var loc = document.location;
						var server = loc.protocol + '//' + loc.hostname;
						$('tree_btn').observe('click', function() {
							window.open('/files/phylowidget/bare.html?tree=' + server + r.files['nw'], 'target_tree', 'status=0,height=500,width=600');
						});
						var tree_ind = $('tree_ind');
						tree_ind.removeClassName('conIndicator_Rb_disabled');
						tree_ind.addClassName('conIndicator_Rb');
					}
					btn_ind.addClassName('conIndicator_not-processed');
				}
				else if (r.status == "done-empty") {
					$('message').update("No homologs found. Search other genomes.");
					btn_ind.addClassName('conIndicator_not-processed');
				}
				else if (r.status == "failed") {
					$('message').update("Failed to get the results from Target.");
					btn_ind.addClassName('conIndicator_error');
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
			width: 800, 
			height: 600,
			shadow: false,
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

function set_source(s) {
	var el = $('seq_src_' + s);
	if (el) {
		el.click();
		populate_fields(s);
		if (s != 'sample') {
			$('sample').selectedIndex = -1;
		}
	}
}

function populate_fields(src) {
	
	var sel = $('sample');
	var organism = $('organism');
	var common_name = $('common_name');
	if (src == 'paste' || !sel || sel.selectedIndex == -1) {
		//organism.value = '';
		//common_name.value = '';
		organism.readOnly = false;
		common_name.readOnly = false;
		$('function').readOnly = false;
		$('class').readOnly = false;
		$('gp_name').readOnly = false;
		//$('type').readOnly = false;
	}
	else {
		var extra = {};
		var o = sel.options[sel.selectedIndex];
		var extra_str = o.hasAttribute('extra') ? o.getAttribute('extra') : null;
		if (extra_str) {
			var data = extra_str.match(/(.*?):(.*?);/g);
			data.each(function(item) {
				var tmp = item.replace(/;/,'').split(/:/);
				if (tmp.size() == 2) {
					extra[tmp[0]] = tmp[1];
				}
			});
		}
		dbg = extra;
		if (extra.name)
			$('gp_name').value = extra.name;
		if (extra.class_name)
			$('class').value = extra.class_name;
		if (extra.function_name)
			$('function').value = extra.function_name;

		var type_o = $('type_' + extra.type);
		var full_name = o.text;
		//organism.value = full_name.replace(/\s*\(.*/,'');
		var m = full_name.match(/\((.*)\)/);
		if (m && m.length == 2) {
			var tmp = m[1].split("/");
			organism.value = tmp[0];
			common_name.value = tmp[1];
		}
		organism.readOnly = true;
		common_name.readOnly = true;
		$('function').readOnly = true;
		$('class').readOnly = true;
		$('gp_name').readOnly = true;
		if (type_o) {
			type_o.checked = true;
		}
	}
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
	
	var params = { 'pid' : $('tid').value, 'public' : np, 'type' : 'target' };
	sent = params;
	new Ajax.Request('/project/update',{
		method:'post',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			var r = response.evalJSON();
			if (r.status == 'success') {
				show_messages("Project updated successfully.");
			}
			else  if (r.status == 'error') {
				show_errors("There seem to be an error: " + r.message);
			}
			else {
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
			}
	});
}

/* triggers when a checkbox is changed */
function updateRunButton(event) {
	var btn_ind = $('launch_btn_ind');
	if (btn_ind.hasClassName('conIndicator_processing')) {
//		console.info('still processing..');
		return;
	}
	var cnt = 0;
	$$('input.conRadiobox_align').each(function(element) {
	  //var element = event.element();
	  //console.info(element.getAttribute('id') + ' ' + element.id);
	  if (element.checked == true) {
		
		cnt++;
	  }
	});
	//console.info(cnt);
	/*conIndicator_Rb_disabled
	  conIndicator_not-processed
	  conIndicator_processing */
	if (cnt) {
		btn_ind.removeClassName('conIndicator_Rb_disabled');
		btn_ind.removeClassName('conIndicator_error');
		//btn_ind.removeClassName('conIndicator_processing');
		btn_ind.addClassName('conIndicator_not-processed');
	}
	else {
		btn_ind.removeClassName('conIndicator_error');
		btn_ind.removeClassName('conIndicator_not-processed');
		//btn_ind.removeClassName('conIndicator_processing');
		btn_ind.addClassName('conIndicator_Rb_disabled');
	}
}

//-------------
// keep this at the end
Event.observe(window, 'load', function() {
	
	// re-check processing routines' status
	if ($('tid')) {
		var tid = $('tid').value;
		var spans = $$('span');
		var btn = $('launch_btn_ind');
		if (btn && btn.hasClassName('conIndicator_processing')) {
			intervalID = setInterval(check_status, 10000, tid, -1);
		}
		
		// load tooltips
		$$('span.conYellowline_ConCell1').each(function(el) {
			if (el.hasAttribute('id') && el.id.indexOf('sg_') == 0) {
				if (el.hasAttribute('cn')) {
					//console.info(el.getAttribute('cn'));
					new Tip(el, el.getAttribute('cn'), {style: 'creamy', width: 'auto', border: 1, radius: 1});
				}
			}
		});

		updateRunButton();
		// set events for checkboxes, so we may trigger update button
		$$('input.conRadiobox_align').each(function(el) {
			if (el.getAttribute('name') == 'g') {
				//console.info("** >" + el.id);
				el.observe('click', updateRunButton);
			}
		});
	}
});
