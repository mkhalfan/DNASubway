// global w to keep track of the popup window

var w;

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

	var options = {	
			resizable: false,
        	width: 360,
	        height: 200,
	        shadow: false,
	        draggable: false
		};
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}
	var _w = new UI.Window(options).center();
	html = "<div class=\"conNewPro_title\" style=\"vertical-align: middle; padding: 20px\">" + html + "</div>";
	/*if (isError) {
		_w.setHeader("Error");
	}
	else {
		_w.setHeader("Notice");
	}*/
	_w.header.removeClassName('move_handle');
	_w.setHeader("Message");
	_w.setContent(html);
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// remove buttons from IE
		try {
			var btns = _w.buttons.childElements();
			btns.each(function(btn){
				if(btn.hasClassName('minimize') || btn.hasClassName('maximize') ) {
					btn.remove();
				}
			});
			_w.setResizable(false);
		} catch (e) {};
	}

	_w.show(true);
	_w.activate();
	return w = _w;
}

function show_errors(html) {

	if (!html || !UI) {
		return;
	}
	return show_messages(html, 1);
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
// from http://www.quirksmode.org/js/cookies.html

function set_cookie(name,value,days) {
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		var expires = "; expires="+date.toGMTString();
	}
	else var expires = "";
	document.cookie = name+"="+value+expires+"; path=/";
}

function get_cookie(name) {
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	for(var i=0;i < ca.length;i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}

function erase_cookie(name) {
	set_cookie(name,"",-1);
}

//------------------------
function show_edit() {
	$('desc_limit_label').show();
	$('conProjectInfo_edit').update('<div class="bt_projectInfo_done"><a href="javascript:;" onclick="update_info();"></a></div><div class="bt_projectInfo_cancel"><a href="javascript:;" onclick="hide_edit();"></a></div>');
	var ddiv = $('description_container');
	ddiv.setAttribute('origdesc', ddiv.innerHTML);
	var ta = new Element('textarea', {id:'description', style:'width:100%;height: 60px;'});
	ta.value = ddiv.innerHTML;
	//onkeyup="check_description_length(event);"
	Event.observe(ta, 'keyup', check_description_length);
	ddiv.update(ta);

	var tdiv = $('conProjectInfo_projecttitle');
	tdiv.setAttribute('origtitle', tdiv.innerHTML);

	var ttl = tdiv.innerHTML.replace(/<.+?>.*<\/.+?>/,'');
	ttl = ttl.replace(/^\s+/,'').replace(/\s+$/,'');
	tdiv.update(new Element('input', {id:'title', type:'text',style:'width:300px;', value: ttl, maxlength: 40}));
}

function hide_edit() {
	$('desc_limit_label').hide();
	$('conProjectInfo_edit').update('<div class="bt_projectInfo_edit"><a href="javascript:;" onclick="show_edit();"></a></div>');
	var ddiv = $('description_container');
	ddiv.update( ddiv.readAttribute('origdesc'));
	var tdiv = $('conProjectInfo_projecttitle');
	tdiv.update(tdiv.readAttribute('origtitle'));
}

function update_info() {
	var ttl = $('title');
	var desc = $('description');
	ttl.value = ttl.value.replace(/^\s+/,'').replace(/\s+$/,'');
	desc.value = desc.value.replace(/^\s+/,'').replace(/\s+$/,'');

	if (ttl.value.length > 40) {
		show_errors("Title should have 40 characters or less.");
		//ttl.focus();
		return;
	}
	if (desc.value.length > 140) {
		show_errors("Description should have 140 characters or less.");
		return;
	}
	var params = { pid : $('pid') ? $('pid').value : $('tid').value, 
					type: $('tid') ? 'target' : 'annotation',
					title : ttl.value, description: desc.value
				};
	//sent = params;
	new Ajax.Request('/project/update', {
		method:'get',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			var r = response.evalJSON();
			if (r.status == 'success') {
				show_messages("Project updated successfully.");
				$('conProjectInfo_projecttitle').writeAttribute('origtitle', ttl.value);
				$('description_container').writeAttribute('origdesc', desc.value);
				hide_edit();
			}
			else  if (r.status == 'error') {
				show_errors("There seems to be an error: " + r.message);
			}
			else {
			}
		},
		onFailure: function(){
				alert("Something went wrong.");
			}
	});
}

//------------------------

function openWindow(url, title, opts) {
	UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;

	var options = opts ? opts : {
		width: 900, 
		height: 496,
		shadow: false,
		draggable: true,
		resizable: true,
		url: url
	};
	
	if (navigator.userAgent.indexOf('MSIE') != -1) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}

	var w = new UI.URLWindow( options ).center();
	if (title) {
		w.setHeader(title);
	}

	var p = w.getPosition();
	w.setPosition(110, p.left);
	w.show();
	w.focus();
	//windows.push(w);
	return w;
}

//------------------------

function launch_tour() {
	var w = openWindow('/files/tour/index.html',
				'DNA Subway tour', {
				width: 750, 
				height: 520,
				shadow: false,
				draggable: true,
				resizable: false,
				url: '/files/tour/index.html'
			}
		);

	if (navigator.userAgent.indexOf('MSIE') != -1) {
		try {
			var btns = w.buttons.childElements();
			btns.each(function(btn){
				if(btn.hasClassName('minimize') || btn.hasClassName('maximize') ) {
					btn.remove();
				}
			});
			w.setResizable(false);
		} catch (e) {};
	}
}

//------------------------

Event.observe(window, 'load', function() {
	// check for errors
	var err = $("error_list");
	if (err) {
		var html = err.innerHTML;
		if (html) {
			w = show_errors(html);
		}
	}
	
	// check messages
	var mess = $("message_list");
	if (mess) {
		var html = mess.innerHTML;
		if (html) {
			w = show_messages(html);
		}
	}
});

Event.observe(document, 'keypress', function(ev) {
	if (ev.keyCode == 27) { //ESC
    	//debug('w=' + w);
	    try {
    	    if (w)
        	    w.close();
	    } catch (e) {}
	}
});
