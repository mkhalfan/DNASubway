var dbg;

function step_one() {
	if (! $('seq_src_upload').checked && !$('seq_src_sample').checked && !$('seq_src_paste').checked) {
		//alert("Source not selected!");
		show_errors("Sequence source not selected!");
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
			show_errors('We only acctept DNA sequences in ' +
					'<a href="http://en.wikipedia.org/wiki/FASTA_format#Format">FASTA format</a>!'
				);
			return;
		}
	}

	if (!has_file && !has_sample && !has_actg) {
		alert("You must select a file to upload or a sample organism!");
		return;
	}
	if (has_sample) {
		//alert("Method not yet supported!");
		//return;
	}
	//$('continue').disabled = true;
	show_errors("Creating project. Stand by..");
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
	        height: 200,
	        shadow: true,
	        draggable: false
		};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}
	var w = new UI.Window(options).center();
	html = "<div class=\"message-error\" style=\"vertical-align: middle\">" + html + "</div>";
	w.setContent(html);
	w.show(true);

}

function pasted_data_ok() {
	var t = $('notebox').value;
	t.replace(/^\s+/,'');
	t.replace(/\s+$/,'');

	// it should start with ">"
	if (!/^>/.test(t)) {
		return false;
	}
	t = t.replace(/>.*/, '');
	if (t.length == 0) {
		return false;
	}
	var re = /[^actgn\s]/i;
	return re.test(t) == false;
}


Event.observe(window, 'load', function() {
	var err = $("error_list");
	if (!err)
		return;
	var html = err.innerHTML;
	if (!html)
		return;
	show_errors(html);
});
