function show_other(parent, triggered, triggerer) {
	//alert(parent + ' ' + id);
	var p = $(parent);
	var t = $(triggered);
	if (p && t) {
		if (p.value == triggerer) {
			t.style.display = document.all ? 'block' : 'table-row';
		}
		else {
			t.style.display = 'none';
		}
	}
}