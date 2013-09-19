var dbg;
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

function load_profile_questions (parent, atqs) {
	var p = $(parent);
	var triggered, triggerer;
	Object.keys( atqs ).each( function(k, i) {
		//alert('::' + i + ':' + k + '<' + atqs[k]);
		if (p.value == atqs[k]) {
			triggerer = atqs[k];
			triggered = k;
			return;
		}
	});

	$$('tr').each(function(tr) {
		if ( tr.hasAttribute('parent') && tr.getAttribute('parent') == parent ) {
			//alert('to remove ' + tr.cells[0].innerHTML + "//" + parent);
			tr.parentNode.removeChild(tr);
		}
	});

	if (triggered && triggerer) {
		var form = document.forms['form_reg'];//$('form_reg');
		$('faction').value = 'reload';
		form.submit();
		/*
		alert("We should load " + triggered);
		new Ajax.Request('/get_profile_node',{
			method:'get',
			parameters: {node: triggered}, 
			onSuccess: function(transport){
				var response = transport.responseText || '';
				//alert(response);
				//console.info('r = ' + response);
				//var r = response.evalJSON();
				//dbg = r;
				alert(response);
				var tr = p.parentNode.parentNode;
				tr.insert({after:response});
			},
			onFailure: function(){
				alert("Something went wrong.");
				clearInterval(intervalID[op]);
			}
		});
		*/
	}

}
