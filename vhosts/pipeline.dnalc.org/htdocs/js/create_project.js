
function step_one() {
	if (! $('seq_src_upload').checked && !$('seq_src_sample').checked && !$('seq_src_paste').checked) {
		//alert("Source not selected!");
		show_messages("Sequence source not selected!");
		return;
	}

	var f = $('forma1');
	var has_file = $('seq_src_upload').checked && ( $('seq_file').value != '' );
	var has_sample = $('seq_src_sample').checked && $('specie').selectedIndex != -1;
	var has_actg = false;
	
	if ($('seq_src_paste').checked) {
		if (pasted_data_ok()) {
			has_actg = true;
		}
		else {
			show_messages('The sequence missing or is invalid.');
			return;
		}
	}

	if (!has_file && !has_sample && !has_actg) {
		show_messages("You must select a file to upload or a sample organism!");
		return;
	}
	
	if ($('name') && $('name').value == '') {
		show_messages("Please provide a title for you project!");
		return;
	}
	
//----------------------------------------
	if (!UI) {
		alert('UI is missing!');
		return;
	}
	var options = {	
			resizable: false,
        	width: 340,
	        height: 180,
	        shadow: false,
	        draggable: false,
			close: false
		};
	/*if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}*/
	var _w = new UI.Window(options).center();
	html = "<p>&nbsp;</p><div class=\"conNewPro_title\" style=\"padding-left: 20px; padding-top: 20px;\">"
		+ "Creating project. Stand by.."
		+ ($('isnew') && $('isnew').value == "1" ? "<p>&nbsp;</p><small>(Your first project may take longer to create.)</small>" : '')
		+ "</div>";
	_w.setHeader("Notice");
	_w.setContent(html);
	_w.show(true);
	_w.activate();
//----------------------------------------

	/*w = show_messages("");
	document.observe('window:destroyed', function(event) {
		if (w.id == event.memo.window.id) {
			$('step_one_btn').onclick = null;
			w = show_messages("Creating project. Do not close this message. <p>Stand by..</p>");
		}
	});*/
	f.submit();
}

function select_source(el) {
	if (el && (el.value == 'upload' || el.value == 'paste')) {
		$('specie').selectedIndex = -1;
	}
	else if (el && el.value == 'sample') {
		//$('organism_info').hide();
	}
	populate_fields(el.value);
}


function set_source(s) {
	var el = $('seq_src_' + s);
	if (el) {
		//el.checked = true;
		el.click();
	}
}

function populate_fields(src) {
	var sel = $('specie');
	var organism = $('organism');
	var common_name = $('common_name');
	if (src == 'upload' || !sel || sel.selectedIndex == -1) {
		//organism.value = '';
		//common_name.value = '';
		organism.readOnly = false;
		common_name.readOnly = false;
	}
	else {
		var o = sel.options[sel.selectedIndex];
		var clade = o.hasAttribute('clade') ? o.getAttribute('clade') : 'o';
		var clade_o = $('g' + clade);
		var full_name = o.text;
		organism.value = full_name.replace(/\s*\(.*/,'');
		var m = full_name.match(/\((.*)\)/);
		if (m && m.length == 2) {
			common_name.value = m[1];
		}
		organism.readOnly = true;
		common_name.readOnly = true;
		if (clade_o) {
			clade_o.checked = true;
		}
	}
}

function use_organism(obj) {
	
	try {
		var org = obj.firstChild.innerHTML;
		var ary = org.split(/,\s+/);
		if (ary && ary.length == 2) {
			$('organism').value = ary[0];
			$('common_name').value = ary[1];
			if (w) // global w, for the curent popup
				w.close();
		}
	}
	catch (e) {}
}


function pasted_data_ok() {
	var t = $('notebox').value;
	t = t.replace(/(?:>|;).*/g, '');
	if (t.length == 0) {
		return false;
	}
	var re = /[^actugn\s\d]/i;
	return re.test(t) == false;
}

/*
function set_organism_typewe(type) {
	if (!type)
		return;
	type = type.toLowerCase().replace(/^\s+/,'').replace(/\s+$/,'');
	$('forma1').insert(new Element('input', {'type': 'hidden', 'id':'type', 'name':'type', 'value':'animals'}));
	get_samples(type);
	$('conProject_dispatcher').hide();
	$('conProject_newLeft').toggle();
	$('conProject_newRight').toggle();
	
	
	$$('#conProject_newRight input[type=radio]').each(function(obj){obj.parentNode.hide()});

	if (type == 'fungi') {
		$('gf').parentNode.show();
	}
	else if (type == 'animals') {
		$('ga').parentNode.show();
	}
	else {
		['gm', 'gd', 'go', 'gu'].each(function(obj) {
				$(obj).parentNode.show();
			});
	}
}
*/

function get_samples(type) {
	// remove current samples
	var ssamples = $('specie').options;
	while(ssamples.length) {
		ssamples[0].remove();
	}

	new Ajax.Request('/project/get_samples',{
		method:'get',
		parameters: { 't': type}, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			var samples = response.evalJSON();
			samples.each (function(s) {
				if (s) {
					var txt = s['organism'] + ' (' + s['common_name'] + ') ' + s['segment'] + ', ' + s['len'];
					$('specie').insert(new Element('option', {id:'o' + s['id'], value:s['id'], 'clade': s['clade']}).update(txt));
				}
			});

		},
		onFailure: function(){
				alert('Something went wrong!\nAborting...');
			}
	});
}
//-------------
// keep this at the end
Event.observe(window, isMSIE ? 'load' : 'dom:loaded', function() {

 //if ($('test2')) {
		/*if ($('otypep').checked) {
			$('clades').show();
			['gm', 'gd', 'go', 'gu'].each(function(obj) {
				$(obj).parentNode.show();
			});
			['ga', 'gf'].each(function(obj) {
				$(obj).parentNode.hide();
			});
		}
		else {
			$('clades').hide();
		}*/

		$$('input[name=otype]').each(function(obj, idx) {
			obj.observe('click', function(){ 
				get_samples(obj.value);
				$$('#conProject_newRight input[type=radio]').each(function(obj){obj.parentNode.hide()});
				if (obj.value == "plants") {
					$('animals_level_2').hide();
					$('plants_level_2').setStyle({display: 'inline-block'});
				}
				else if (obj.value == "animals") {
					$('plants_level_2').hide();
					$('animals_level_2').setStyle({display: 'inline-block'});
				}
				else {
					$('animals_level_2').hide();
					$('plants_level_2').hide();
				}
				
				$$('#forma1 input,textarea,select').each(function(obj){
				  if (obj.id.indexOf('otype')) obj.enable();
				});
				if ($('otypep').prototip){
					$('otypep').prototip.remove();
				}
			});
			//console.info(obj);
		});
		
		$$('#forma1 input,textarea,select').each(function(obj){
		  if (obj.id.indexOf('otype')) obj.disable();
		});
		
		var tip = new Tip('otypep', " &nbsp;Start here!", {
				//title: "Start here",
				border: 5,
				radius: 5,
				style: 'red',
                stem: 'leftMiddle',
                hook: { mouse: false, tip: 'leftMiddle' },
                offset: { x: 110, y: 5 },
                width: 90,
				hideAfter: 5,
				hideOn: '',
			});
		$('otypep').prototip.show();
/*
	}
	else {
		//alert("no");
		$('conProject_dispatcher').hide();
	}*/
});