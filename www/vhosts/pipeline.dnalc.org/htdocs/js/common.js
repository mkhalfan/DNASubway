// global w to keep track of the popup window

var w;
var isMSIE = Prototype.Browser.IE;

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
function warning_message(warning) {
        return '\
	<table><tr><td><img src="/images/warning-1.png" height="30px" /></td> \
        <td>'+warning+'</td></tr></table>';
}

function show_messages(html, isError, height, width) {
	height = null;
	width = null;
	try {
		if (!html || !UI) {
			//alert(html);
			return;
		}
	} catch (e) {
		return;
	}

	var options = {	
			resizable: false,
        	width:  width  || 360,
	        height: height || 200,
	        shadow: false,
	        draggable: false
		};
	if (isMSIE) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}
	var _w = new UI.Window(options).center();
	html = "<div class=\"messages\">" 
		+ html
		+ "<div style=\"text-align: center;margin-top: 20px;\"><input id=\"msg_ok_btn\" class=\" &nbsp; OK &nbsp; \" type=\"button\" value=\"OK\" onclick=\"w.close();\"/></div>"
		+ "</div>";

	_w.header.removeClassName('move_handle');
	_w.setHeader("Message");
	_w.setContent(html);
	if (isMSIE) {
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
	var msg_ok_btn = $('msg_ok_btn');
	if (msg_ok_btn)
		msg_ok_btn.focus();
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
/*
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
 */
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
	var ptype = 'annotation';
	{
		var path = window.location.pathname;
		var m = path.match(/\project\/(target|phylogenetics|ngs)/);
		if (m && m.length == 2) {
			ptype = m[1];
		}
		if (ptype == 'ngs'){
			ptype = 'NGS';
		}
	}
	var params = { pid : $('pid') ? $('pid').value : $('tid').value, 
					type: ptype,
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
	//UI.defaultWM.options.blurredWindowsDontReceiveEvents = true;
	UI.WindowManager.setOptions({zIndex: 20000});

	var options = opts ? opts : {
		width: 900, 
		height: 496,
		shadow: false,
		draggable: true,
		resizable: true,
		url: url
	};
	
	if (isMSIE) {
		// IE doen't like this option!!!
		delete options['resizable'];
	}

	//var w = url && url.indexOf('.gff') > 1 ? new UI.Window( options ) : new UI.URLWindow( options );
	var w = new UI.URLWindow( options );
	w.center();
	if (title) {
		w.setHeader(title);
	}
	
	/*if (url && url.indexOf('.gff') > 1) {
		new Ajax.Request(url, {
			method:'get',
			//parameters: params, 
			onSuccess: function(transport){
				var response = transport.responseText || "#No data to display.";
				w.setContent('<pre>' + response + '</pre>');
			},
			onFailure: function(){
				alert("Something went wrong.");
			}
		});
	}*/

	var p = w.getPosition();
	w.setPosition(110, p.left);
	w.show();
	w.focus();

	return w;
}

//------------------------

function launch_tour() {
	var w = openWindow('/files/tour/index.html',
				'DNA Subway tour', {
				width: 758, 
				height: 528,
				shadow: false,
				draggable: false,
				resizable: false,
				url: '/files/tour/index.html'
			}
		);
	w.header.removeClassName('move_handle');

	if (isMSIE) {
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

function launch_greenline_preview() {
	var w = openWindow('/files/gl-preview.html',
				'Green Line Preview', {
				width: 575, 
				height: 375,
				shadow: false,
				//draggable: false,
				resizable: false,
				url: '/files/gl-preview.html'
			}
		);
	w.header.removeClassName('move_handle');

	if (isMSIE) {
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
function launch_background() {
	var w = openWindow('/files/dynamic_gene/index.html',
				'DNA Subway Background Information', {
				width: 960, 
				height: 580,
				shadow: false,
				draggable: false,
				resizable: false,
				url: '/files/dynamic_gene/index.html'
			}
		);
	w.header.removeClassName('move_handle');

	if (isMSIE) {
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
function launch_help() {
	var w = openWindow('/about/help',
				'DNA Subway Help', {
				width: 600, 
				height: 400,
				shadow: false,
				draggable: false,
				resizable: false,
				url: '/about/help'
			}
		);
	w.header.removeClassName('move_handle');

	if (isMSIE) {
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
function set_public(np) {
	if ($('public_yes').disabled)
		return;

	if (np) {
		$('public_yes').checked = true;
		$('public_no').checked = false;
	}
	else {
		$('public_yes').checked = false;
		$('public_no').checked = true;
	}
	
	$('public_yes').disabled = true;
	$('public_no').disabled = true;
	
	// stop hammering the db
	new PeriodicalExecuter(function(p){
				$('public_yes').disabled = false;
				$('public_no').disabled = false;
				p.stop();
		}, 5);
	var ptype = 'annotation';
	{
		var path = window.location.pathname;
		var m = path.match(/\project\/(target|phylogenetics)/);
		if (m && m.length == 2) {
			ptype = m[1];
		}
	}
	var params = { 'pid' : $('pid') ? $('pid').value : $('tid').value, 
				'public' : np, 
				'type': ptype 
			};
	sent = params;
	new Ajax.Request('/project/update',{
		method:'post',
		parameters: params, 
		onSuccess: function(transport){
			var response = transport.responseText || "{'status':'error', 'message':'No response'}";
			//debug(response);
			var r = response.evalJSON();
			if (r.status == 'success') {
				show_messages("Project updated successfully.");
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

/* import from greenline / GFF toggles used in the redline console and create_project screen */
 function show_gl_data(){
	$('import_from_gl_space').update('<iframe src=\'get_ngs_exports.html\' id=\'gl_iframe\'></iframe>');
	$('evidence_uploads').hide();
	$('import_from_gl_space').show();
	$('gl_iframe').onload = function() {
		var iframeHeight = $('gl_iframe').contentWindow.document.getElementById('import_from_greenline').getHeight();
		$('gl_iframe').setStyle({height: (iframeHeight + 23) + 'px'});
		$('import_from_gl_browse').hide();
		$('import_from_gl_cancel').show();
	}
}
function close_gl_data(){
	$('import_from_gl_cancel').hide();
	$('import_from_gl_browse').show();
	$('import_from_gl_space').hide();
	$('evidence_uploads').show();
	$('gff_container').hide();
}
/* END import from greenline / GFF toggles used in the redline console and create_project screen */



//------------------------

Event.observe(window, isMSIE ? 'load' : 'dom:loaded', function() {
	// check for errors
	var err = $("error_list");
	if (err) {
		var html = err.innerHTML;
		if (html) {
			w = show_errors(html);
			return;
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

$(document).keydown(function(e) {
    if (e.keyCode === 8 || e.keyCode === 8) {
        var element = e.target.nodeName.toLowerCase();
        if ((element != 'input' && element != 'textarea') || $(e.target).attr("readonly")) {
            alert('delete');
	    return false;
        }
    }
}); 

