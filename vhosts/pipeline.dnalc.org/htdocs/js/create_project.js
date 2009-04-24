function step_one() {
	var f = $('forma1');
	var has_file = $('seq_file').value != '';
	var has_sample = $('specie').selectedIndex != '-1';
	if (!has_file && !has_sample) {
		alert("You must upload file or select a sample organism!");
		return;
	}
	//alert(has_file + '-' + has_sample);
	f.submit();
}
/*
function step_one_jquery() {
	var f = $("#forma1");
	var has_file = $("#seq_file").val() != '';
	var has_sample = $("#specie").selectedIndex != '';
	if (!has_file && !has_sample) {
		alert("You must upload file or select a sample organism!");
		return;
	}
	//alert(has_file + '-' + has_sample);
	f.submit();
}*/
