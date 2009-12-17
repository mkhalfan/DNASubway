var dbg, w;

function step_one() {
	if (! $('seq_src_upload').checked && !$('seq_src_sample').checked && !$('seq_src_paste').checked) {
		//alert("Source not selected!");
		show_message("Sequence source not selected!", 1);
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
			show_message('The sequence is invalid.', 1);
			return;
		}
	}

	if (!has_file && !has_sample && !has_actg) {
		alert("You must select a file to upload or a sample organism!");
		return;
	}

	var w = show_message("Creating project. Do not close this message. <p>Stand by..</p>");
	document.observe('window:destroyed', function(event) {
		if (w.id == event.memo.window.id) {
			$('step_one_btn').onclick = null;
			w = show_message("Creating project. Do not close this message. <p>Stand by..</p>");
		}
	});
	f.submit();
}

function select_source(el) {
	if (el && el.value == 'upload') {
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

function show_message(html, isError) {

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
	
	// defined earlier as a global variable
	_w = new UI.Window(options).center();
	html = "<div class=\"conNewPro_title\" style=\"vertical-align: middle; padding: 20px\">" + html + "</div>";
	_w.setContent(html);
	if (isError) {
		_w.setHeader("Error");
	}
	_w.show(true);
	_w.activate();
	return _w;
}

function use_organism(obj) {
	
	try {
		var org = obj.firstChild.innerHTML;
		var ary = org.split(/,\s+/);
		if (ary && ary.length == 2) {
			$('organism').value = ary[0];
			$('common_name').value = ary[1];
			_w.close();
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


Event.observe(window, 'load', function() {
	var err = $("error_list");
	if (!err)
		return;
	var html = err.innerHTML;
	if (!html)
		return;
	show_message(html, 1);
});
