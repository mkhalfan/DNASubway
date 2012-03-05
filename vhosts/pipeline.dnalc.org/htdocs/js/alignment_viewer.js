function zoomIn() {
	var width = $('div_width').value;
	if (width == 12){
		$('sequence').addClassName('bases');
		$('div_width').value='13';
		$('zoom_in').disabled = true;
		$('sequence_but').disabled = true;
	}
	else if (width == 8){
		$('barcode').hide();
		$('sequence').show();
		$('sequence').removeClassName('bases');			
		$('div_width').value='12';			
	}
	else{
		$$('#barcode div div').each(function(el) {
			el.setStyle({
				width: 2*width + 'px',
			});
		});
		$('div_width').value=2*width;
	}
	$('zoom_out').disabled = false;
	$('barcode_but').disabled = false;
}
function zoomOut() {
	var width = $('div_width').value;
	if (width > 12){
		$('sequence').removeClassName('bases');
		$('div_width').value='12';
	}
	else if (width == 12){
		$('sequence').hide();
		$('barcode').show();
		$$('#barcode div div').each(function(el) {
			el.setStyle({
				width: '8px',
			});
		});			
		$('div_width').value='8';
	}
	else {
		$$('#barcode div div').each(function(el) {
			el.setStyle({
				width: width/2 + 'px',
			});
		});
		var new_width = width/2
		$('div_width').value= new_width;
		if (new_width == 1){
			$('zoom_out').disabled = true;
			$('barcode_but').disabled = true;
		}
	}
	$('zoom_in').disabled = false;
	$('sequence_but').disabled = false;
}
function barcodeView() {
		$('sequence').hide();
		$('barcode').show();	
		$$('#barcode div div').each(function(el) {
			el.setStyle({
				width: '1px',
			});
		});
		$('div_width').value='1';
		$('zoom_in').disabled = false;
		$('sequence_but').disabled = false;
		$('zoom_out').disabled = true;
		$('barcode_but').disabled = true;
}
function seqView() {
		$('barcode').hide();
		$('sequence').show();	
		$('sequence').addClassName('bases');
		$('div_width').value='13';
		$('zoom_in').disabled = true;
		$('sequence_but').disabled = true;
		$('zoom_out').disabled = false;
		$('barcode_but').disabled = false;
}
function resizeFrame(f) {
	f.style.height = (f.contentWindow.document.body.scrollHeight + 20) + "px";
}
document.observe("dom:loaded", function() {
	$('div_width').value = $$('#barcode div div')[0].getStyle('width').split('px')[0];
	$('zoom_out').disabled = true;
	$('barcode_but').disabled = true;
	$('zoom_in').disabled = false;
	$('sequence_but').disabled = false;
});