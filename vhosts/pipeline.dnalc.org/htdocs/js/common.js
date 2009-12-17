function gl_hide_definition() {
	$$('span.con_GlossaryTextbox').each(function(sp) {
		if (sp.style.display == 'block') {
			//console.info("**: " + sp.style.display + "|" + sp.innerHTML);
			sp.style.display = 'none';
		}
	});
}

function gl_show_definition(el) {
	gl_hide_definition();
	//alert($(el).ancestors()[1].next().innerHTML);
	//alert(el.parentNode.parentNode.next());
	$(el).ancestors()[1].next().style.display = 'block';
}