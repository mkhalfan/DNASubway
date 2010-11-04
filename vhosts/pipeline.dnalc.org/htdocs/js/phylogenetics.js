	var pairs = [];
	var current_pair = [];
	//var seq2pairs = {};
	
(function() {
	// keep open windows

	var step = 0;
	var windows = {};
	
	phy = function() {
		this.task_states = {};
		
	};
	
	phy.create_project = function () {

		var ptype = '';
		$$('input[type=radio]').each(function(el,i) {
			if (el.name.match(/^type/) && el.checked) {
				ptype = el.value;
			}
		});

		if (ptype == '') {
			show_messages("Please provide a type for this project!");
			return;
		}

		if (! $('seq_src_upload').checked && !$('seq_src_paste').checked) {
			//alert("Source not selected!");
			show_messages("Sequence source not selected!");
			return;
		}

		var has_file = $('seq_src_upload').checked && ( $('seq_file').value != '' );
		//var has_sample = $('seq_src_sample').checked && $('specie').selectedIndex != -1;
		var has_actg = false;

		if ($('seq_src_paste').checked) {
			var pasted_data_ok = function() {
				var t = $('seq_paste').value;
				t = t.replace(/(?:>|;).*/g, '');
				if (t.length == 0) {
					return false;
				}
				var re = /[^actugn\s\d]/i;
				return re.test(t) == false;
			};
			if (pasted_data_ok()) {
				has_actg = true;
			}
			else {
				show_messages('The sequence is missing or invalid!');
				return;
			}
		}

		if (!has_file && !has_actg) {
			show_messages("You must select a file to upload!");
			return;
		}
		
		if ($('name') && $('name').value == '') {
			show_messages("Please provide a title for you project!");
			return;
		}

		//-------------------------------------------------------
		// show modal window
		if (!UI) {
			alert('UI is missing!');
			return;
		}
		var options = {	
				resizable: false,
				width: 340,
				height: 180,
				shadow: false,
				draggable: false,
				close: false
			};
		var _w = new UI.Window(options).center();
		var html = "<p>&nbsp;</p><div class=\"conNewPro_title\" style=\"padding-left: 20px; padding-top: 20px;\">"
			+ "Creating project. Stand by.."
			+ "</div>";
		_w.setHeader("Notice");
		_w.setContent(html);
		_w.show(true);
		_w.activate();
		//-------------------------------------------------------

		var f = $('forma1');
		f.submit();
	};
	
	phy.select_source = function (el) {
		if (el && (el.value == 'upload' || el.value == 'paste')) {
			//$('specie').selectedIndex = -1;
		}
		else if (el && el.value == 'sample') {
			//$('organism_info').hide();
		}
		//populate_fields(el.value);
	};

	phy.set_source = function(s) {
		var el = $('seq_src_' + s);
		if (el) {
			el.click();
		}
	};
	
	phy.launch = function (what, where, title) {
		
		var urls = {
				viewer: ['/project/phylogenetics/tools/view_sequences.html?pid=', 'View Sequences'],
				pair: ['/project/phylogenetics/tools/pair?pid=', 'Pair sequences'],
				data: ['/project/phylogenetics/tools/add_data?pid=', 'Phytozome Browser'],
				add_ref: ['/project/phylogenetics/tools/add_ref?pid=', 'Add Reference'],
				manage: ['/project/prepare_chadogbrowse?warn=1;pid=', 'Phylogenetic Tree']
			};

		try {
			//$('add_evidence').hide();
			//$('add_evidence_link').show();
		}
		catch (e) {}

		if (what && !urls[what]) {
			alert('Nothing to load!!');
			return;
		}

		var host = window.location.host;
		var uri = what 
						? 'http://' + host + urls[what][0] + $('pid').value
						: where;
		var window_title = title ? title : urls[what] ? urls[what][1] : null;
		windows[what] = openWindow( uri, window_title);
		
		debug(what + ': ' + windows[what]);
		
		/*try {
			pageTracker._trackEvent(title, "view");
		} catch (e) {
			debug(e.toString());
		};*/
	};
	
	// pairing
	phy.push_to_pair = function (id) {
		if (current_pair.indexOf(id) == -1) {
			current_pair.push(id);
		}
		if (current_pair.length == 2) {
			phy.add_pair(current_pair);
			current_pair = [];
		}
	};

	phy.add_pair = function(pair) {
		pair.each(function(el) {
			//console.info('to add BG ' + el);
			$(el).addClassName(pairs.length % 2 ? 'paired-light' : 'paired-dark');
			//seq2pairs[el] = pairs.length;
		});

		pairs.push(pair);
		if ($('do_pair') != null && $('do_pair').disabled) {
			$('do_pair').disabled = false;
		}
	};
	
	phy.pop_from_pair = function(id) {
		var idx = current_pair.indexOf(id);
		if ( idx != -1) {
			delete current_pair[idx];
			current_pair = current_pair.compact();
		}
		else {
			//alert('pop ' + pairs.length);
			for(var i = 0; i < pairs.length; i++) {
				if (pairs[i][0] == id || pairs[i][1] == id) {
					//console.info('removed pair ' + pairs[i]);
					[0,1].each(function(k) {
						$(pairs[i][k]).removeClassName('bold');
						$(pairs[i][k]).removeClassName('paired-light');
						$(pairs[i][k]).removeClassName('paired-dark');
						$('op' + pairs[i][k]).checked = false;
						//console.debug($('op' + pairs[i][k]));
						//delete seq2pairs[pairs[i][k]];
					});
					delete pairs[i];
					pairs = pairs.compact();
					break;
				}
			}
		}
		if ($('do_pair') != null && $('do_pair').disabled) {
			$('do_pair').disabled = false;
		}
	};
	
	phy.toggle_strand = function(el, norclbl) {
		debug(el);
		var id = el.id.replace(/^rc/, '');
		
		if (norclbl == undefined) {
			if (el.innerHTML == "R")
				el.innerHTML = "F";
			else if (el.innerHTML == "F")
				el.innerHTML = "R";
		}

		if (el.hasAttribute("rc")) {
			el.setAttribute("rc", el.getAttribute("rc") == "1" ? "0" : "1");
		}
		else {
			el.setAttribute("rc", "1");
		}

		if ($(id)) {
			var seq = $(id).innerHTML;
			var revcom = [];
			var rev = seq.split('').reverse();
			for (var i =0; i < rev.length; i++) {
				let = rev[i];
				switch (let) {
					case 'A':
						revcom.push('T');
						break;
					case 'T':
						revcom.push('A');
						break;
					case 'C':
						revcom.push('G');
						break;
					case 'G':
						revcom.push('C');
						break;
					default:
						revcom.push(let);
				}// end switch
			}// end for
			$(id).innerHTML = revcom.join('');
		}// end if
	};
	
	phy.do_pair = function() {
		var lpairs = [];
		/*$('seqops').descendants().each(function(el){
			if (el.nodeName == "A") {		
				var id = el.id.replace(/^\D+/, '');

				console.info(el.getAttribute("pair")
					+ " " + $(id).id
					+ " " + el.getAttribute("rc")
				);

				var pair = {'id' : id, 
							'rc' : el.getAttribute("rc") == "1" ? 1 : 0,
							'pair' : el.getAttribute("pair") ? el.getAttribute("pair") : 0
						};
				lpairs.push(pair);
			}
			//console.info(el);
		});*/
		pairs.each(function(p,index){
			//console.info(p + " " + index);
			var lpair = [];
			p.each(function(id) {
				var a = $('rc' + id);
				lpair.push([id, a.hasAttribute("rc") ? a.getAttribute("rc") : "0"]);
			});
			lpairs.push(lpair);
		});

		debug(lpairs.toJSON());

		$('data').value = lpairs.toJSON();
		var form = $('forma1');
		form.submit();
		if (null != windows['pair']) {
			windows['pair'].close();
		}
	};
	
	phy.set_status = function(op, status) {
		var p = $('pid').value;
		var b = $(op + '_btn');
		var ind = $(op + '_st');
		
		if (status == 'processing') {
			b.onclick = null;
			ind.removeClassName(ind.className);
			ind.addClassName('conIndicatorBL_processing');
		}
		else if (status == 'done') {
			ind.removeClassName(ind.className);
			ind.addClassName('conIndicatorBL_done');
			if (op == 'phy_pair')
				return;
			var uri = op;
			uri = uri.replace(/phy_/, "view_");
			b.onclick = function(){
					phy.launch(null, '/project/phylogenetics/tools/' + uri + '?pid=' + p, '');
				};
		}
		else if (status == 'not-processed') {
			ind.removeClassName(ind.className);
			ind.addClassName('conIndicatorBL_not-processed');
			b.onclick = function(){ phy.run(op); };
		}
	};
	
	phy.run = function(op) {
		debug("op = " + op);
		//var s = $(op);
		var b = $(op + '_btn');
		var p = $('pid').value;
		var ind = $(op + '_st');

		phy.set_status(op, "processing");
		/*
		if (b) {
			b.onclick = null;
			//b.removeClassName(b.className);
			//b.addClassName('disabled');
		}
		if (ind) {
			ind.removeClassName(ind.className);
			ind.addClassName('conIndicatorBL_processing');
			//ind.title = 'Processing';
		}
		*/
		
		/*
			var delay = b ? parseFloat(b.getAttribute('delay')) : 10;
			delay = !isNaN(delay) ? (delay * 1000) : 10000;
		*/

		var uri = op;
		uri = uri.replace(/phy_/, "build_");
		new Ajax.Request('/project/phylogenetics/tools/' + uri,{
			method:'get',
			parameters: { 't' : op, pid : p}, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				debug(response);
				var r = response.evalJSON();
				//debug(r);
		
				if (r.status == 'success') {
					/*ind.removeClassName(ind.className);
					ind.addClassName('conIndicatorBL_done');
					var uri = op;
					uri = uri.replace(/phy_/, "view_");
					b.onclick = function(){
							phy.launch(null, '/project/phylogenetics/tools/' + uri + '?pid=' + p, '');
						};
					*/
					phy.set_status(op, "done");
					if (op == "phy_alignment") {
						phy.set_status("phy_tree", "not-processed");
						debug("set Tree to not-processed");
					}
				}
				else  if (r.status == 'error') {
					b.removeClassName(b.className);
					b.addClassName('error');
					
					ind.removeClassName(ind.className);
					ind.addClassName('conIndicatorBL_error');
					//ind.title = 'Error';
					b.onclick = function(){phy.run(op);};
					
					show_errors(r.message);
				}
				else {
					//s.update('Unknown status!');
					//alert('Unknown status!');
				}
			},
			onFailure: function(){
					alert('Something went wrong!\nAborting...');
				}
		});
		
		/*try {
			pageTracker._trackEvent(rnames[op] || op, "run");
		} catch (e) {
			debug(e.toString());
		};*/
	};
	
	phy.do_add_ref = function() {
		var pid = $('pid').value;
		var refid = $('refid').value;
		//alert(pid + ' ' + refid);
		if (refid && pid) {
			$('buttonas').disabled = true;
			var f = $('forma1');
			$('ref_id').value = refid;
			f.submit();
		}
	};
	
	phy.close_window = function(id) {
		if (null != windows[id]) {
			windows[id].close();
			debug("change stauts if it's the case....");
		}
	};

})();

function debug(msg) {
	try {
		var d = $('debug');
		if (d) d.update(msg);
		if (console) console.info(msg);
	}
	catch (e) {}
}

Event.observe(window, Prototype.Browser.IE ? 'load' : 'dom:loaded', function() {
	step = $('step') ? parseInt($('step').value, 10) : 0;
	//console.info("step = " + step);

	if (step == 1) {
		$('seqops').down().descendants().each(function(sp){
		  if (sp.type && sp.type == "checkbox") {
			Event.observe(sp, 'click', function(ev){
				var el = Event.element(ev);
				//el.checked = false;
				var id = el.id.replace(/^op/,'');
				//console.info(id + " " + el.id);
				//console.info(el.checked);
				if (el.checked) {
					$(id).addClassName('bold');
					phy.push_to_pair(id);
				}
				else {
					$(id).removeClassName('bold');
					phy.pop_from_pair(id);
				}
			});
		  }
		});
		// init pairs
		pairs = $('data').value.evalJSON();
		pairs.each(function(pair, cnt) {
			pair.each(function(el){
				var a_rc = $('rc' + el);
				//console.info(el + ' ' + a_rc.innerHTML);
				if (a_rc && a_rc.innerHTML == "R") {
					phy.toggle_strand(a_rc, 1);
				}
			});
		});
		if ($('do_pair') != null)
			$('do_pair').disabled = true;
	}
	else if (step == 2) {
		
	}
});