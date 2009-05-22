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
	$('continue').disabled = true;
	f.submit();
}

function select_source(el) {
	if (el && el.value == 'upload') {
		$('specie').selectedIndex = -1;
		//$('organism_info').show();
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
		organism.value = '';
		common_name.value = '';
		organism.readOnly = false;
		common_name.readOnly = false;
	}
	else {
		var o = sel.options[sel.selectedIndex];
		var full_name = o.text;
		organism.value = full_name.replace(/\s*\(.*?\)/,'');
		var m = full_name.match(/\((.*)\)/);
		if (m && m.length == 2) {
			common_name.value = m[1];
		}
		organism.readOnly = true;
		common_name.readOnly = true;

	}
}

