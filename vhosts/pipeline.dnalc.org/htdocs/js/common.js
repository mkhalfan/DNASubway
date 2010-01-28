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

//------------------------
function show_messages(html, isError) {
	if (!html || !UI) {
		//alert(html);
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
	var _w = new UI.Window(options).center();
	html = "<div class=\"conNewPro_title\" style=\"vertical-align: middle; padding: 20px\">" + html + "</div>";
	if (isError) {
		_w.setHeader("Error");
	}	
	_w.setContent(html);
	_w.show(true);
	_w.activate();
	return _w;
}

function show_errors(html) {

	if (!html || !UI) {
		return;
	}
	show_messages(html, 1);
}
//------------------------

function check_description_length(e) {

	var node = (e.target) ? e.target : ((e.srcElement) ? e.srcElement : null);
	$('desc_len').innerHTML = node.value.length;
	if (node.value.length >= 141) {
		show_messages('Maximum 140 chars for the description.');
		node.value = node.value.substr(0, 140);
		$('desc_len').innerHTML = node.value.length;
		node.blur();
	}
}
//------------------------

function skip_detection () {
	var ua = navigator.userAgent;
	var re1 = /msie/i;
	var re2 = /win/i;
	var re3 = /opera/i;
	return re3.test(ua) || re1.test(ua) && re2.test(ua);
}
//------------------------

function webstartVersionCheck(versionString) {
	// skip detection for IE, Opera browsers
	if (skip_detection())
		return true;

    // Mozilla may not recognize new plugins without this refresh
    //navigator.plugins.refresh(true);
	var hasJnlp = false;
	var hasApplet = false;
    // First, determine if Web Start is available
    if (navigator.mimeTypes['application/x-java-jnlp-file'])
		hasJnlp = true;
	// Next, check for appropriate version family
	for (var i = 0; i < navigator.mimeTypes.length; ++i) {
		pluginType = navigator.mimeTypes[i].type;
		//console.info(pluginType);
		if (pluginType == "application/x-java-applet;version=" + versionString) {
			hasApplet = true;
			break;
		}
	 }
	return hasApplet || hasJnlp;
 }
//------------------------

Event.observe(window, 'load', function() {
	// check for errors
	var err = $("error_list");
	if (err) {
		var html = err.innerHTML;
		if (html) {
			show_errors(html);
		}
	}
	
	// check messages
	var mess = $("message_list");
	if (mess) {
		var html = mess.innerHTML;
		if (html) {
			show_messages(html);
		}
	}
});