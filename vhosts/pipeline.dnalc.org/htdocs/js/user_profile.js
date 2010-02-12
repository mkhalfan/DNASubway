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

function load_profile_questions (parent, triggered, triggerer) {
	var p = $(parent);
	if (p.value == triggerer) {
		alert("we should load " + triggered);
	}
	else {
		//alert("we should remove them..");
		$$('tr').each(function(s) {
			// table.remove...
			console.info(s.getAttribute('parent'));
		});

	}
}