var dbg;

function step_one() {
	if (! $('seq_src_upload').checked && !$('seq_src_sample').checked) {
		alert("Source not selected!");
		return;
	}

	var f = $('forma1');
	var has_file = $('seq_src_upload').checked && ( $('seq_file').value != '' );
	var has_sample = $('seq_src_sample').checked && $('specie').selectedIndex != -1;
	if (!has_file && !has_sample) {
		alert("You must select a file to upload or a sample organism!");
		return;
	}
	if (has_sample) {
		//alert("Method not yet supported!");
		//return;
	}
	//$('continue').disabled = true;
	f.submit();
}

function select_source(el) {
	if (el && el.value == 'upload') {
		$('specie').selectedIndex = -1;
		//$('sample_info').update('');
	}
	else if (el && el.value == 'sample') {
		//$('organism_info').hide();
	}
	populate_fields(el.value);
}

function show_sample_info() {
	return;
	var si = $('sample_info');
	var species = $('specie');
	var extra = species.options[species.selectedIndex].getAttribute('extra');
	si.update(extra);
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


function show_errors(html) {

	if (!html || !UI) {
		return;
	}
	var resizable = true;
	var options = {	
			resizable: false,
        	width: 400,
	        height: 300,
	        shadow: true,
	        draggable: false
		};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}
	var w = new UI.Window(options).center();
	w.setContent(html);
	w.show(true);
}

Event.observe(window, 'load', function() {
	var err = $("error_list");
	if (!err)
		return;
	var html = err.innerHTML;
	if (!html)
		return;
	html = "<div class=\"message-error\">" + html + "</div>";
	show_errors(html);
});
