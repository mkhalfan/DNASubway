//---

function run (op) {
	var s = $(op);
	var b = $(op + '_btn');
	if (b) b.disable();
	if (s) s.update(new Element('img', {'src' : '/images/ajax-loader.gif'}));
}

