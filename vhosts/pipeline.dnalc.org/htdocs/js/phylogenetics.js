	var _dbg;
	var pairs = [];
	var current_pair = [];
(function() {
	// keeps open windows
	var windows = {};
	var intervalID = {};
	var xZoom = 1;
	var yZoom = 1;
	var yLimit = 80; // max y a trace can have, so the graph stays in the canvas
	var titles = {
		phy_pair : "Pair Builder",
		phy_trim : "Sequence Trimmer",
		phy_consensus : "Consensus Editor",
		phy_alignment : "Alignment Viewer",
		phy_tree : "PHYLIP NJ",
		phy_tree_ml : "PHYLIP ML"
	};
	

	phy = function() {
		this.task_states = {};
		
	};

	phy.auto_pair = function () {
		var k = 0;
		var divz = $$('#seqids pre div');
		var ldivz = divz.length - 1;
		
		var pair_cnt = 0;

		while (k < ldivz) {
			//--
			var a = divz[k].innerHTML;
			var b = divz[++k].innerHTML;

			var shortest = a.length > b.length ? b : a;
			var lshortest = shortest.length;
			var mism = "";
			var i = 0;
			for (; i < lshortest; i++) {
				if (a.charAt(i) != b.charAt(i)) {
					mism = a.charAt(i) + b.charAt(i);
					break;
				}
			}

			if (i > lshortest/2 && mism != "" && /^[RF]/i.test(mism)) {
				// if already paired manually, skip it
				var chkb = $$('#opdiv_' + divz[k].id.replace(/^id_/, '') + ' input')[0];
				if (chkb.style.display != 'none') {
					// if A.innerHTML == R, don't reverse complement it anymore
					var anchor1 = $$('#opdiv_' + divz[k-1].id.replace(/^id_/, '') + ' a')[0];
					var anchor2 = $$('#opdiv_' + divz[k].id.replace(/^id_/, '') + ' a')[0];
					if (anchor2.innerHTML !="R" && (mism.charAt(1) == "R" || mism.charAt(1) == "r")) {
						phy.toggle_strand(anchor2);
					}
					else if (anchor1.innerHTML !="R" && (mism.charAt(0) == "R" || mism.charAt(0) == "r")) {
						phy.toggle_strand(anchor1);
					}
					phy.add_pair([ divz[k-1].id.replace(/^id_/, ''), divz[k].id.replace(/^id_/, '') ]);
					pair_cnt++;
				}
				k++;
			}
			//k++;
		}
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

		if (! $('seq_src_upload').checked && !$('seq_src_paste').checked 
				&& !$('seq_src_sample').checked && !$('seq_src_dnalc').checked) {
			//alert("Source not selected!");
			show_messages("Sequence source not selected!");
			return;
		}

		var has_file = $('seq_src_upload').checked && ( $('seq_file').value != '' );
		var has_actg = false;
		var has_sample = $('seq_src_sample').checked && $('sample').selectedIndex >= 0;
		var has_dnalc_file = $('seq_src_dnalc').checked && ( $$('input[name=d]').value != '' );

		if ($('seq_src_paste').checked) {
			var pasted_data_ok = function() {
				var t = $('seq_paste').value;
				t = t.replace(/(?:>|;).*/g, '');
				if (t.length == 0) {
					return false;
				}
				//var re = /[^actugn\s\d]/i;
				//return re.test(t) == false;
				return true;
			};
			if (pasted_data_ok()) {
				has_actg = true;
			}
			else {
				show_messages('The sequence is missing or invalid!');
				return;
			}
		}

		if (!has_file && !has_actg && !has_sample && !has_dnalc_file) {
			show_messages("You must select a file to upload!");
			return;
		}
		
		if ($('name') && $('name').value == '') {
			show_messages("Please provide a title for your project!");
			return;
		}

		//-------------------------------------------------------
		// show modal window
		if (!UI) {
			alert('Error: Some of the UI components were not loded properly!');
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
	
	phy.select_source = function (src) {
		if (!src)
			return;

		
		if(src != 'genbank' && src != 'bold'){
			if ($('accession') && $('import_btn')){
				$('accession').disabled=true;
				$('import_btn').disabled=true;
			}
		}
		

		if (src == 'importdnalc') {
			var pid = parent.document.getElementById('pid').value;
			document.location.replace('./dnalc_data?pid=' + pid);
		}
		else if (src == 'newdnalc') {
			if ($('transferred_files'))
				$('transferred_files').show();
			else
				phy.launch(null, './tools/dnalc_data?pid=new', 'Import DNALC data');
		}			
		else if (src == 'genbank' || src == 'bold') {
			$('accession').disabled=false;
			$('import_btn').disabled=false;
		}
		else {
			$('dnalc_container').update();
			if ($('transferred_files'))
				$('transferred_files').hide();
		}
	};

	phy.set_source = function(s) {
		var el = $('seq_src_' + s);
		if (el) {
			el.click();
		}
	};
	
	phy.import_request = function () {
		var pid = parent.document.getElementById('pid').value;
		var src = $('forma1').getInputs('radio', 'seq_src').find(
			function(re) {return re.checked;}
		);
		//var src = checked.value;
		//$('import_btn').observe('click', function(ev) {
			$('import-error').hide();
			$('import_btn').disabled=true;
			if ($('accession').value){
				var accession = $('accession').value;
				phy.get_external_data(accession, pid, src.value);
			}
			else{
				$('import-error').update('Please enter an accession/process ID');
				$('import-error').show();
				$('import_btn').disabled=false;
			}
		//});
	};
	
	phy.get_external_data = function(accession, pid, src) {
		if (!src)
			return;
		
		$('import-loader').show();

		new Ajax.Request('/project/phylogenetics/tools/import_from_' + src, {
			method:'get',	
			parameters: {'pid': pid, 'accession': accession},
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r.status == 'success') {
					$('import-loader').hide();
					//if (src == 'genbank' && r.message == 'too-big'){
						//top.show_messages('');
					//}
					if (src == 'genbank') {
						top.show_messages(r.message);
					}
					top.phy.close_window('data');
				}
				else {
					$('import-loader').hide();
					$('accession').value = '';
					$('import-error').show();
					$('import-error').update('Error: ' + r.message);
					$('import_btn').disabled=false;
					
				}
			},
			onFailure: function(){
					alert('Something went wrong!\nAborting...');
				}
		});
	}
	
	phy.launch = function (what, where, title) {
		
		var urls = {
				viewer: ['/project/phylogenetics/tools/view_sequences.html?pid=', 'Sequence Viewer'],
				phy_trim: ['/project/phylogenetics/tools/view_sequences.html?show_trimmed=1;pid=', 'Trimmed Sequence Viewer'],
				pair: ['/project/phylogenetics/tools/pair?pid=', 'Pair Builder'],
				blast: ['/project/phylogenetics/tools/blast.html?pid=', 'BLASTN'],
				data: ['/project/phylogenetics/tools/add_data?pid=', 'Add data'],
				ref: ['/project/phylogenetics/tools/add_ref?pid=', 'Reference Data'],
				manage_sequences: ['/project/phylogenetics/tools/manage_sequences?pid=', 'Select Data']
			};

		try {
			//$('add_evidence').hide();
			//$('add_evidence_link').show();
		}
		catch (e) {}

		/*if (what && !urls[what]) {
			alert('Nothing to load!!');
			return;
		}*/

		var host = window.location.host;
		var uri = what && urls[what]
						? 'http://' + host + urls[what][0] + $('pid').value
						: where;
		var window_title = title ? title : urls[what] ? urls[what][1] : null;
		
		
		var options = null;
		if (what == 'manage_sequences') {
			options = {
				width: 900, 
				height: 496,
				shadow: false,
				draggable: true,
				resizable: true,
				url: uri, 
				close : function() {
					if (what && windows[what]) {
						/*if ($(windows[what].content.down().contentWindow.document).getElementById('selection_changed').value != "") {
							if (!confirm("You haven't saved your selection.\nDo you really want to close this window?")) {
								return false;
							}
						}*/
						windows[what].destroy(); 
						return true;  
					}
				}
			};
		}
		
		windows[what] = openWindow( uri, window_title, options);
		
		//debug(what + ': ' + windows[what]);
	};
	
	//---------------------------------------------------------------
	// pairing related functions
	//
	phy.push_to_pair = function (id) {
		if (current_pair.indexOf(id) == -1) {
			current_pair.push(id);
		}
		if (current_pair.length == 2) {
			var opdiv = $('opdiv_' + id);
			function remove_tip(clear_selection) {
				opdiv.prototip.remove();
				if (clear_selection) {
					current_pair.each(function(iid) {
							$('op' + iid).checked = false;
							$('op' + iid).enable();
						});
				}
				current_pair = [];
			}
			var tipContent = new Element('div').update( "Would you like to pair these two sequences?");
			tipContent.insert(			
				new Element('div', {style: 'text-align: center;'})
					.insert(new Element('input', {type: 'button', value: "Yes", id: "pair_yes_btn"})
						.observe('click', function(ev){phy.add_pair(current_pair);remove_tip();})
						.observe('custom:focus', function(ev){ev.target.focus();ev.target.stopObserving('custom:focus');})
						)
					.insert(new Element('input', {type: 'button', value: "No", id: "pair_no_btn"})
						.observe('click', function (ev){/*phy.pop_from_pair(id);*/remove_tip(true);}))
			);

			//var tip = new Tip('op' + id, tipContent, {
			var tip = new Tip('opdiv_' + id, tipContent, {
				title: "Pair them?",
				style: 'protogrey',
				stem: 'rightMiddle',
				showOn: 'click',
				hideOn: 'click',
				//hideOn: { element: 'closeButton', event: 'click' },
				hook: { mouse: false, tip: 'rightMiddle' },
				offset: { x: 15, y: 10 },
				width: 200
			});

			current_pair.each(function(iid) {
					$('op' + iid).disable();
				});

			opdiv.prototip.show();
			setTimeout("$('pair_yes_btn').fire('custom:focus')", 100);

		}
	};

	phy.add_pair = function(pair) {
		var classname = pairs.length % 2 ? 'paired-light' : 'paired-dark';
		pair.each(function(el) {
			$(el).addClassName(classname);
			$('id_' + el).addClassName(classname);
			$('op' + el).hide();
			if ($('pb' + el)) {
				$('pb' + el).removeClassName('paired-dark');
				$('pb' + el).removeClassName('paired-light');
				$('pb' + el).addClassName(classname);
				$('pb' + el).style.visibility = 'visible';
			}
			//seq2pairs[el] = pairs.length;
		});
		$('selection_changed').show();
		try{
			$('try_auto').hide();
			$('reset').show();
		}
		catch(err) {};

		pairs.push(pair);
		if ($('do_pair') != null && $('do_pair').disabled) {
			$('do_pair').disabled = false;
		}
	};
	
	phy.pop_from_pair = function(id) {
		$('selection_changed').show();
		var idx = current_pair.indexOf(id);
		if ( idx != -1) {
			debug('pop_from_pair: found in current_pair at pos: ' + idx);
			delete current_pair[idx];
			current_pair = current_pair.compact();
		}
		else {
			for(var i = 0; i < pairs.length; i++) {
				if (pairs[i][0] == id || pairs[i][1] == id) {

					[0,1].each(function(k) {
						$(pairs[i][k]).removeClassName('bold');
						$(pairs[i][k]).removeClassName('paired-light');
						$(pairs[i][k]).removeClassName('paired-dark');
						$('id_' + pairs[i][k]).removeClassName('paired-dark');
						$('id_' + pairs[i][k]).removeClassName('paired-light');
						$('op' + pairs[i][k]).parentNode.removeClassName('paired-dark');
						$('op' + pairs[i][k]).parentNode.removeClassName('paired-light');
						$('op' + pairs[i][k]).checked = false;
						$('op' + pairs[i][k]).enable();
						$('op' + pairs[i][k]).show();
						if ($('pb' + pairs[i][k])) {
							$('pb' + pairs[i][k]).style.visibility = 'hidden';
							$('pb' + pairs[i][k]).update(' ');
							if ($('pb' + pairs[i][k]).hasAttribute('pair_id')) {
								$('rm_pairs').value += $('pb' + pairs[i][k]).getAttribute('pair_id') + ",";
							}
						}
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

	// visual representation of revers complementing a requence
	//
	phy.toggle_strand = function(el, norclbl) {
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
			
			$(id).innerHTML = phy.rev_com(seq).join('');
		}// end if
	};
	
	phy.rev_com = function(seq){
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
		return revcom;
	};
	
	phy.do_pair = function() {
		var lpairs = [];

		pairs.each(function(p,index){
			var lpair = [];
			p = p.sort(function (a,b){ return a - b;});
			p.each(function(id) {
				var a = $('rc' + id);
				lpair.push([id, a.hasAttribute("rc") ? a.getAttribute("rc") : "0"]);
			});
			lpairs.push(lpair);
		});

		if (lpairs.length == 0 && $('has_pairs').value == "0")
			return;

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
		var title = titles[op];
		ind.removeClassName(ind.className);

		if (status == 'processing') {
			b.onclick = null;
			ind.addClassName('conIndicatorBL_processing');
		}
		else if (status == 'done') {
			ind.addClassName('conIndicatorBL_done');
			if (op == 'phy_pair')
				return;
			var uri = op;
			uri = uri.replace(/phy_/, "view_");
			uri = uri.replace(/tree_ml$/, "tree");
			b.onclick = function(){
					phy.launch(op, '/project/phylogenetics/tools/' + uri + '?pid=' + p + ';t=' + op, title);
				};
		}
		else if (status == 'not-processed') {
			ind.addClassName('conIndicatorBL_not-processed');
			b.onclick = function(){ phy.run(op); };
		}
		else if (status == 'disabled') {
			ind.addClassName('conIndicatorBL_disabled');
			b.onclick = null;
		}
		else if (status == 'error') {
			ind.addClassName('conIndicatorBL_error');
			b.onclick = function(){ phy.run(op); };
		}
	};
	
	phy.run = function(op) {
		//debug("op = " + op);
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
		uri = uri.replace(/tree_ml$/, "tree");
		new Ajax.Request('/project/phylogenetics/tools/' + uri,{
			method:'get',
			parameters: { 't' : op, pid : p, rnum: Math.random(2001) + Math.random(12001)}, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
		
				if (r.status == 'success') {
					phy.set_status(op, "done");
					if (op == "phy_alignment") {
						phy.set_status("phy_tree", "not-processed");
						phy.set_status("phy_tree_ml", "not-processed");
					}
					else if (op == "phy_trim") {
						if (/done$/.test($('phy_pair_st').className)) {
							phy.set_status("phy_consensus", "not-processed");
						}
					}
				}
				else  if (r.status == 'error') {
					phy.set_status(op, "error");
					/*
					b.removeClassName(b.className);
					b.addClassName('error');
					
					ind.removeClassName(ind.className);
					ind.addClassName('conIndicatorBL_error');
					//ind.title = 'Error';
					b.onclick = function(){phy.run(op);};
					*/
					
					show_errors(r.message);
				}
				else {
					//s.update('Unknown status!');
					//alert('Unknown status!');
				}
			},
			onFailure: function(){
					phy.set_status(op, "error");
					alert('Something went wrong (' + op + ')!\nAborting...');
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
		var refid;
		var f = $('forma1');
		f.getInputs().each(function(el) {
			if (el.type == 'radio' && el.name == 'refid' && el.checked) {
				refid = el.value;
			}
		});

		if (refid && pid) {
			$('buttonas').disabled = true;
			$('ref_id').value = refid;
			f.submit();
		}
	};
	
	phy.close_window = function(id) {
		if (null != windows[id]) {
			windows[id].close();
			delete windows[id];
		}
	};
	
	phy.draw_qvalues = function() {
		var canvas = $('canvas1');
		if (canvas.getContext){
			var padding = 10;
			var font = "16px Courier";
			
			var colors = ['#00299c', '#0884ce', '#c6ffff'];
			var ctx = canvas.getContext('2d');

			// data
			var qual = [];
			var str  = $('seq_data').value;
			var qval = $('qvalues').value;
			qval.split(',').each(function(q){
					//debug(q);
					qual.push(parseInt(q, 10));
				});

			// get text's size and resize the canvas
			ctx.font = font;
			ctx.fillStyle = "Black";
			var metrics = ctx.measureText(str);
			var text_width = metrics.width;
			canvas.width = text_width + 2*padding;

			var char_width = text_width/str.length;

			// draw the text
			ctx.font = font;
			ctx.fillText(str, padding, 30);
			//return;
			// draw quality scores
			var qual_str = '';
			for (var q in qual) {
				var aq = parseInt(qual[q]/10);
				qual_str = qual_str.concat(aq);
				var h = 3 * aq;
				var qcol = qual[q] > 30
						? colors[2]
						: qual[q] > 20
							? colors[1]
							: colors[0];
				var x = padding + q*char_width + 2;
				ctx.fillStyle = qcol;
				ctx.fillRect(x, 55 - h + 1, 6, h + 1);
			}
		}
	};
	
	
	//---------------------------------------------------------
	//
	//---------------------------------------------------------
	 phy.zoomReset = function() {
		$('zoom_reset').disabled = true;
		yZoom = xZoom = 1;
		//phy.draw();
		phy.prepare_draw();
		$('zoom_reset').disabled = false;
	}
	phy.zoomIn = function(axis) {
		$(axis + '_zoom_in').disabled = true;
		var zVar = axis + 'Zoom';
		eval(zVar + " *= 1.3");
		phy.prepare_draw();
		$(axis + '_zoom_in').disabled = false;
	}

	phy.zoomOut = function(axis) {
		$(axis + '_zoom_out').disabled = true;
		var zVar = axis + 'Zoom';
		eval(zVar + " /= 1.3");
		phy.prepare_draw();
		$(axis + '_zoom_out').disabled = false;
	}
	//---------------------------------------------------------
	phy.prepare_draw = function() {
		
		// Get the data
		var display_id = $('seq_display_id').value;
		
		var sequence = $('seq_data').value;
		var baseLocations = [];
		var qualityScores = [];
		var traces = {};
		
		var qval = $('qvalues').value;

		// Put the data in the right format (array)
		qval.split(',').each(function(q){
				var val = parseInt(q, 10);
				if (!isNaN(val))
					qualityScores.push(val);
			});
			
		$('b_locations').value.split(',').each(function(q){
				baseLocations.push(parseInt(q, 10));
			});
		['A', 'T', 'C', 'G'].each(function(base, i) {
			var arr = [];
			$('seq_' + base).value.split(',').each(function(b){
				arr.push(parseInt(b, 10));
			});
			traces[base] = arr;
		});
		
		// Trim the data if show_trimmed is true
		if ($('show_trimmed').value == "1"){
			var start = $('start').value;
			var end = $('end').value;
			
			sequence = sequence.substring(start, end);
			baseLocations = baseLocations.slice(start, end);

			qualityScores = qualityScores.slice(start, end);
			['A', 'T', 'C', 'G'].each(function(base, i) {
				traces[base] = traces[base].slice(baseLocations[0], baseLocations[baseLocations.length - 1]);
			});
		}
		
		var data = {
			seq_display_id : display_id,
			sequence : sequence,
			qscores : qualityScores,
			trace_values: traces,
			base_locations: baseLocations
		};

		phy.draw(data, 'canvas1');
	};
	//---------------------------------------------------------
	
	phy.draw = function(data, canvasID) {
	
		var canvas = $(canvasID);       
		if (!canvas.getContext)
			return;
			
		var padding = 5;
		var height = 200;
		var baseCallYPos = 30;
		var qualScoreSectionHeight = 30;
		var qualScoreYPos = baseCallYPos + qualScoreSectionHeight;
		var baseLocationYPos = 70;
		var ctx = canvas.getContext('2d');
		
		var title = data['seq_display_id'];
		var sequence = data['sequence'];
		var qualityScores = data['qscores'];
		var a_trace_values = data['trace_values']['A'];
		var t_trace_values = data['trace_values']['T'];
		var c_trace_values = data['trace_values']['C'];
		var g_trace_values = data['trace_values']['G'];
		var a_color = 'green';
		var t_color = 'red';
		var c_color = 'blue';
		var g_color = 'black';
		var baseLocations = data['base_locations']; // The position of the base in the entire sequence
		var baseLocationsPositions = []; // The position of the base on the canvas (in our subsequence)
		
		// 'reverse_flag' only exists for the consensus sequence. If it is set to true (1), 
		// this sequence and trace needs to be reverse complemented. 
		if (data['reverse_flag'] == 1){
			// Reverse complement the sequence
			sequence = phy.rev_com(sequence).join('');
			
			// Reverse the quality scores and trace values
			// The are stored as array lists, so we can use reverse()
			qualityScores = qualityScores.reverse();
			a_trace_values = a_trace_values.reverse();
			t_trace_values = t_trace_values.reverse();
			c_trace_values = c_trace_values.reverse();
			g_trace_values = g_trace_values.reverse();
			
			// Change the trace colors to match the complements
			var a_color = 'red';
			var t_color = 'green';
			var c_color = 'black';
			var g_color = 'blue';
		}
		
		var offset = 0;
		// 'offset' only exists for the consensus sequence. If represents how many
		// bases the consensus trace should be offset by, in the event that there are
		// less than 3 nucleotides in the sequence preceeding the base in question. 
		// The purpose of this is to put the base in question in the middle of the mini
		// consensus trace canvas (in between the 2 vertical lines) for a consistent look. 
		//
		// This function offsets the base locations, q scores, and sequence by the
		// required offset (1 - 3). The trace itself is offset in the drawTrace fxn.
		if (data['offset'] && data['offset'] != 0){
			offset = data['offset'];
			var startingPoint = baseLocations[0];
			for (var i = 1; i <= offset; i++){
				baseLocations.splice(i - 1, 0, startingPoint - ((offset-i+1)*15));
				qualityScores.splice(0, 0, 0);
				sequence = " " + sequence;
			}
		}
		
		// Normalize the base locations to baseLocationsPositions
		for (var b = 0; b < baseLocations.length; b++){
			baseLocationsPositions[b] = baseLocations[b] - baseLocations[0];
		}
		
		var lastBase = Math.max.apply(Math, baseLocationsPositions);
		
		// Calculate the width of the canvas.
		// If it's the consensus editor, make it the width of the Display ID (unless the trace
		// runs longer than than the Display ID, then set it to the width of the trace).
		// If it's the View Sequences (entire sequence), make it the width of the entire sequence.
		// ('seq_id' is only passed from the consensus editor - that's how we check)
		if (data['seq_id']){
			if (ctx.measureText(title).width > lastBase){
				canvas.width = ctx.measureText(title).width + 15;
				}
			else{
				canvas.width = lastBase + 15;
			}
		}
		else {
			canvas.width = lastBase * xZoom + 15;
		}
	
		function drawTrace(n, color){
			ctx.strokeStyle = color;
			ctx.beginPath();		
			ctx.moveTo(padding + (offset * 15), height - padding);
			n.each(function(x, i) {
				var y = height - padding - x * yZoom;
				
				if (y < yLimit){
					y = yLimit;
				}
				
				ctx.lineTo(padding + (i * xZoom) + (offset * 15), y);
			});
			ctx.stroke();
			ctx.closePath();
		}
		
		drawTrace(a_trace_values, a_color);
		drawTrace(t_trace_values, t_color);
		drawTrace(c_trace_values, c_color);
		drawTrace(g_trace_values, g_color);

		// Draw The Labels
		ctx.fillStyle = "black";
		ctx.fillText(title, padding, 15);
		ctx.fillText("Quality", padding, 43); 
		ctx.fillText("Trace", padding, 83);
		ctx.fillStyle = "rgba(0, 0, 0, 0.1)";
		ctx.fillRect(padding - 2, 4, ctx.measureText(title).width + 4, 14);
		ctx.fillRect(padding - 2, 32, 38, 14);
		ctx.fillRect(padding - 2, 72, 31, 14);
		
		// Draw the 'Quality Score = 20' line (99% accuracy line)
		// Setting line to 5 instead of 20 since I will divide all 
		// the QS's by 4 (so they fit in the designated height of 50px)
		ctx.strokeStyle = "#33CCFF";
		ctx.beginPath();
		ctx.moveTo(padding, qualScoreYPos - 5.5);
		ctx.lineTo(canvas.width - padding, qualScoreYPos - 5.5);
		ctx.stroke();
		ctx.closePath();
		
		// Draw The Base Calls at the appropriate base locations
		var i = 0;
		//for (var x in baseLocations){
		baseLocationsPositions.each(function(bl, i) {
			var base = sequence.charAt(i);
			switch (base){
				case 'A':
				ctx.fillStyle = "green";
  				break;
				case 'T':
		  		ctx.fillStyle = "red";
  				break;
				case 'C':
  				ctx.fillStyle = "blue";
  				break;
				case 'G':
  				ctx.fillStyle = "black";
  				break;
				case 'N':
  				ctx.fillStyle = "black";
  				break;
			}
			ctx.fillText(base, padding + bl * xZoom, baseCallYPos);

			if (!data['seq_id']){
				if ((i + 1)%10 == 0){
					ctx.fillStyle = "black";
					ctx.fillText(i + 1, padding + bl * xZoom - 3, baseLocationYPos);
				}
			}
		});
						
		// Draw The Quality Score Bars
		// The width of the Quality Score bar is calculated in this way so 
		// that it matches the width of a single nucleotide base call no			
		// matter what font or size it is. 
		// Note: I'm dividing the quality score values by 4 so eveything fits
		// in the designated 50px area
		var nucleotideWidth = ctx.measureText(sequence).width / sequence.length;
		ctx.fillStyle = "rgba(0, 0, 200, 0.5)";

		if (qualityScores.length) {
			baseLocationsPositions.each(function(bl, i) {
				ctx.fillRect(
						padding + bl * xZoom, qualScoreYPos - qualityScores[i]/4, 
						nucleotideWidth, qualityScores[i]/4
					);
			});
		}
		else{
			ctx.fillStyle = "black";
			ctx.fillText("Alert: No quality scores for this trace file", 50, 43); 
			ctx.fillStyle = "rgba(255, 255, 0, 0.2)";
			ctx.fillRect(48, 32, 192, 14);
		}
		
		// Draw lines surrounding base in question (for consensus only)
		if (data['seq_id']){
			ctx.fillStyle = "#666666";
			ctx.fillRect(baseLocationsPositions[3] + 3, baseCallYPos - 10, 0.5, 185);
			ctx.fillRect(baseLocationsPositions[3] + 13, baseCallYPos - 10, 0.5, 185);
		}
	};
	
	phy.do_blast = function (sid) {
		var params = { sid : sid, pid: $('pid').value};
		$$("#seqops pre")[0].hide();
		$("seqops").addClassName('blast_processing');
		new Ajax.Request('/project/phylogenetics/tools/do_blast',{
			method:'post',
			parameters: params, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				
				//alert(r.status);
				if (r && r.status == 'success') {
					
					if (r.bid) {
						document.location.href = '/project/phylogenetics/tools/view_blast'
							+ '?bid=' + r.bid
							+ ';pid=' + $('pid').value
							+ ';sid=' + sid; 
							
						/*$$("#seqops pre")[0].show();
						$("seqops").removeClassName('blast_processing');
						$(sid).update("<a href='/project/phylogenetics/tools/view_blast?bid=" + r.bid + ";pid=" + $('pid').value + ";sid=" + sid + "' style='color:red'>View</a>");*/
						
					}
					else {
						$$("#seqops pre")[0].show();
						$("seqops").removeClassName('blast_processing');
						alert("Some error occured " + r.message);	
					}
				}
				else {
					$$("#seqops pre")[0].show();
					$("seqops").removeClassName('blast_processing');
					alert("Error: " + r.message);
					/*if (show_messages) {
						show_messages(r.message);
					}
					else {
						alert("Error: " + r.message);
					}*/
				}
			},
			onFailure: function(){
				alert('Something went wrong!\nAborting...');
				$$("#seqops pre")[0].show();
				$("seqops").removeClassName('blast_processing');
			}
		});
	};
	
	phy.add_blast_data = function (bid) {
		$('add_to_project_btn').disable();
		var sel = [];
		$$('div.tcell input[name=selected_results]').each(function(el) {
			if (el.checked)
				sel.push(el.value);
		});
		new Ajax.Request('/project/phylogenetics/tools/add_blast_data',{
			method:'post',
			parameters: { bid : bid, pid: $('pid').value, selected_results : sel},
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r && r.status == 'success') {
					top.phy.set_status('phy_alignment', 'not-processed');
					top.phy.close_window('blast');
					if (r.message) {
						top.show_messages(r.message);
					}
				}
				else {
					alert("Error: " + r.message);
					$('add_to_project_btn').enable();
				}
			},
			onFailure: function(){
				$('add_to_project_btn').enable();
				alert('Something went wrong!\nAborting...');
			}
		});
	};
	
	// ---------------------------------------------------------------
	// sends a request to EOL.org to get the data for the wanted words
	//
	phy.getEOLData = function(words, tip_content_div) {
	
		new Ajax.Request('/project/phylogenetics/tools/get_eol_data', {
			method: 'get',
			parameters: { q : words },
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r && r.status == 'success') {
					// update our div with the eol info
					var eolh = tip_content_div.select('#eol_header').first();
					//eolh.insert(new Element('span').update("<strong>EOL</strong>: "));

					if (r.data && r.data.length > 0) {
						r['data'].each(function(d, i) {
							if (i > 2) {
								eolh.insert('<span> '
									+ '<a target=\"_blank\" '
									+	'href="http://www.eol.org/search?ie=UTF-8&search_type=text&q=' 
									+ 	escape(words) + '">more</a>'
									+ '</span>'
									);

								throw $break;
							}
							eolh.insert(new Element('span', {style: 'padding-left: 4px;'}).update(
								new Element('a', {href: d['link'], target: '_blank'}).update(d['title'])
							));
						});
					} // end if_r.status==success
					else {
						eolh.insert(new Element('span').update("No entries"));
					}
				} // end else_r.status==success
				else {
					alert("Error: " + r.message);
				}
			},
			onFailure: function(){
				alert('Something went wrong!\nAborting...');
			}
		});
	};

	// ---------------------------------------------------------------
	// sends a request to wikipedia to get the data for the wanted words
	//
	phy.getWikiData = function(words) {
		var apiUri = "http://en.wikipedia.org/w/api.php?"
					+ "action=query&format=json&callback=_parseWikiData&prop=revisions&rvprop=content&rvsection=0&redirects&titles=";
		var uri = apiUri + escape(words);
		var elem = new Element('script', {src: uri, title: 'text/javascript'});
		$$('head').first().insert(elem);
	};

	// callback called when wikipedia data is ready
	// 
	_parseWikiData = function (content) {

		if ( typeof content == "object" ) {
			//tmp_arr.each(function(str, index) {
			//console.info('parsing..');
			Object.keys(content).each(function(k,v) {
				//console.info(k + ' ' + content[k]);
				//if (/)
				if ( k == "*" ) {
					var desc = content["*"];
					
					//_dbg = desc;
					desc = desc.replace(/\n/g, 'NewLine$')
							.replace(/<ref.*?>.*?<\/ref>/g, '')
							.replace(/{{.+?}}/mg, '')
							.replace(/NewLine\$/g, '\n')
							.replace(/''+/g, '')
							.replace(/\[\[(?:.*\|)*?(.+?)\]\]/mg, '$1')
							.replace(/^\s+/, '');

					// only the 1st 20 words...
					var short_desc = desc.split(/\W+/).splice(0, 20).join(' ');
					short_desc += " ... ";
					_displayWikiData(short_desc);
					
				}
				// sometimes the term is not found in wikipedia..
				else if (k == "missing") {
					_displayWikiData('No entries');
				}
				else  {
					_parseWikiData(content[k]);
				}
			});
		} else {  
			//console.info(typeof content);
		}
	};
	
	// ---------------------------------------------------------------
	// 
	_displayWikiData = function(content) {
		
		// since we may have more then one wiki_header divs ...
		var wikidiv = null;
		$$("div.prototip").each(function(el, i) {
			//console.info(i + " " + el.style.display);
			if (el.style.display != 'none') {
				wikidiv = el;
				throw $break;
			}
		});

		if (wikidiv) {
			var more_re = /\s\.{3}\s$/;
			if (more_re.test(content)) {
				// get the term we're displaying
				var title = wikidiv.select('#wiki_header').first().innerHTML;
				//content.replace(more_re, '');
				content += "<a target=\"_blank\" href=\"http://en.wikipedia.org/wiki/" + escape(title) + "\">more</a>";
			}

			// update our div with the wiki info
			wikidiv.select('#wiki_header').first().update(
					"<strong>Wikipedia:</strong> " + content
				);
		}
	};
	
	//---------------------------------------------------------------
	// google search triggers this callback when data is available.
	//
	_searchComplete = function(searcher, el) {

		// main div in the tooltip
		var contentDiv = new Element('div', 'tipcontent');

		// init Wikipedia search
		phy.getEOLData(el.innerHTML, contentDiv, el.id);

		// init Wikipedia search
		phy.getWikiData(el.innerHTML);

		contentDiv.insert(new Element('div', {id:'wiki_header'}).update(el.innerHTML))
				.insert(new Element('div', {id:'eol_header'}).update(new Element('span').update("<strong>EOL</strong>: "))
			);

		// Check that we got results
		if (searcher.results && searcher.results.length > 0) {
			var imagesDiv = new Element('div', 'images');
			contentDiv.insert(imagesDiv);

			// Loop through our results, printing them to the page.
			var results = searcher.results;
			var imgContainer = new Element('div');
			for (var i = 0; i < results.length; i++) {
				// For each result write it's title and image to the screen
				var result = results[i];

				var newImg = new Element('img', {style: "padding: 2px;"});
				// There is also a result.url property which has the escaped version
				newImg.src = result.tbUrl;

				imgContainer.insert(newImg);

				// Put our title + image in the content
				imagesDiv.insert(imgContainer);
			}
			var t = new Tip(el.id, contentDiv, {
						title : el.innerHTML,
						style: 'blue',
						hideOn: { element: 'closeButton', event: 'click' },
						hook: { target: 'bottomMiddle', tip: 'topLeft' },
						offset : {x: 20, y: 10},
						stem: { height: 12, width: 15 },
						hideOthers: true
						//delay: 0.3
					});
			el.prototip.show();
			el.onclick = null;
		}
    };

	// initiates the search, on success, the data is parsed
	// and displayed in _searchComplete function
	phy.get_ggl_image = function(el) {
		if (!el)
			return;
		var query = el.innerHTML;
		if (!query)
			return;
		var imageSearch = new google.search.ImageSearch();
		// Restrict to extra large images only
		// imageSearch.setRestriction(google.search.ImageSearch.RESTRICT_IMAGESIZE,
        //                         google.search.ImageSearch.IMAGESIZE_MEDIUM);
		imageSearch.setSearchCompleteCallback(this, _searchComplete, [imageSearch, el]);
		imageSearch.execute(query);
	};
	
	phy.submit_trimmed_alignment = function () {
		if (!document.applets.Jalview) {
			alert("Unable to obtain the trimmed alignment!");
			return;
		}
		var aln_length = $('aln_length') ? parseInt($('aln_length').value,10) : NaN;
		if (!isNaN(aln_length)) {
			var algn = document.applets.Jalview.getAlignment("fasta", false);
			algn += ""; // fix mac weird stuff
			//algn = document.applets.Jalview.getAlignment("fasta");
			algn = algn.replace(/>.+\n/g,'>\n')
			algn = algn.replace(/\n/g,'')
			var tmp_arr = algn.split('>');
			//tmp_arr.pop(); // we don't need the 1st empty value
			var trimmed = false;
			tmp_arr.each(function(str, index) {
				if (str.length > 0 && str.length != aln_length) {
					trimmed = true;
					//return;
				}
			});
			if (!trimmed) {
				alert('No trimming has been detected!');
				return;
			}
			
			var f = $('forma1');
			$('data').value = document.applets.Jalview.getAlignment("fasta", 'false');
			f.submit();
		}
	};

	phy.show_tips = function () {
		
	};

	phy.type_chosen_handler = function(type) {
		phy.get_samples(type);
		$$('input[name=seq_src]').each(function(el) {
			//debug(type + " " + el.id);
			if (type == "protein" && el.id == "seq_src_dnalc") {
				el.disabled = true;
				el.checked = false;
			}
			else {
				el.disabled = false;
				if ($('transferred_files'))
					$('transferred_files').hide();
			}
		});
	};
	phy.get_samples = function(type) {
		// remove current samples
		var ssamples = $('sample').options;
		while(ssamples.length) {
			ssamples[0].remove();
		}
		
		new Ajax.Request('/project/phylogenetics/get_samples',{
			method:'get',
			parameters: { 't': type}, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var samples = response.evalJSON();
				samples.each (function(s) {
					if (s) {
						$('sample').insert(new Element('option', {id:'o' + s['id'], value:s['id']}).update(s['name']));
					}
				});

			},
			onFailure: function(){
					alert('Something went wrong!\nAborting...');
				}
		});
	};
	
	/*
	 * 
	 *
	 *
	 */
	phy.getDashPositions = function(seq) {

		// LDP = Last Dash Position
		var forwardLDP = 0; 
		var reverseLDP = 0; 
		var substr;
		var startStop = [];
		
		for (var i = 0; i <= seq.length; i++){
			substr = seq.substring(i);
			if (substr.charAt(0) == '-'){
				forwardLDP++;
				substr = substr.substring(i + 1);
			}
			else{
				break; 
			}
		}
		for (i = seq.length-1; i >=0; i--){
			substr = seq.substring(i);
			if (substr.charAt(0) == '-'){
				reverseLDP++;
				substr = substr.substring(i - 1);
			}
			else{
				break; 
			}
		}
		startStop.push(forwardLDP - 1, seq.length - reverseLDP);
		return startStop;
	};
	
	
	/*
	 * Displays the alignment in the consensus editor, 
	 * highlighting any mismatches between the sequences
	 * (typically forward, reverse, and consensus sequences)
	 *
	 */
	phy.show_mismatches = function () {
		var seq1 = $('seq1').value;
		var seq2 = $('seq2').value;
		var display_name_1 = $('display_name_1').value;
		var display_name_2 = $('display_name_2').value;
		var consensus = $('consensus').value;
		var re = /[N-]/;

		var sequenceLength = seq1.length;
		var consensus_span, seq1_span, seq2_span;
		
		$('seq1_name').update(display_name_1);
		$('seq2_name').update(display_name_2);
		$('consensus_div_name').update("Consensus");
		$('colons').show();
		//$('save_changes_btn').show();
		
		var startStop1 = phy.getDashPositions(seq1);
		var startStop2 = phy.getDashPositions(seq2);
		
		var start = Math.max(startStop1[0], startStop2[0]);
		var stop = Math.min(startStop1[1], startStop2[1]);;

		var y = 0;
		for ( var i = 0; i < sequenceLength; i++){
			
			//if ( (!re.test(seq1.charAt(i)) || !re.test(seq2.charAt(i))) 
			if ((i > start && i < stop) && (seq1.charAt(i) != 'N' && seq2.charAt(i) != "N")
					&& (consensus.charAt(i - y) != seq1.charAt(i) || consensus.charAt(i - y) != seq2.charAt(i) )
						&& (seq1.charAt(i) != "-" && seq2.charAt(i) != "-")
				) 
			{
			
				/*if (i > start && i < stop && seq1.charAt(i) == '-'){
					debug(i);
					consensus_span = new Element('span').update(' ').insert(consensus.charAt(i));
					seq1_span = new Element('span').update(seq1.charAt(i));
					seq2_span = new Element('span').update(seq2.charAt(i));
					y++;
				}
				else{ */
				
					//temp = "<span class='non-match'>" + consensus.charAt(i) + "</span>";
					//span = new Element('span', {class: 'non-match', 'position': i, 'base': consensus.charAt(i)}).update(consensus.charAt(i));
					consensus_span = new Element('span', {id: 'con' + i, 'position': i, 'base': consensus.charAt(i)}).update(consensus.charAt(i));
					seq1_span = new Element('span', {'position': i, 'base': consensus.charAt(i - y)}).update(seq1.charAt(i));
					seq2_span = new Element('span', {'position': i, 'base': consensus.charAt(i - y)}).update(seq2.charAt(i));
					
					seq1_span.addClassName('non-match');
					seq2_span.addClassName('non-match');
					consensus_span.addClassName('non-match');
					
					Event.observe(consensus_span, 'click', phy.view_mismatch_trace);
					Event.observe(seq1_span, 'click', phy.view_mismatch_trace);
					Event.observe(seq2_span, 'click', phy.view_mismatch_trace);
				//}
			}
			else{
				//temp = "<span>" + consensus.charAt(i) + "</span>";
				consensus_span = new Element('span', {'position': i+1}).update(consensus.charAt(i));
				seq1_span = new Element('span').update(seq1.charAt(i));
				seq2_span = new Element('span').update(seq2.charAt(i));
			}
			
			$('consensus_div_seq').insert(consensus_span);
			$('seq1_div').insert(seq1_span);
			$('seq2_div').insert(seq2_span);
			
			// Initially, set the save_changes_button to be disabled
			$('save_changes_btn').disabled = true;
		} 
		
		// We load the 'trim consensus' button as being having display:none (inline css)
		// because we want the button to appear only after the alignment has loaded. 
		// So now, we can set it to display. 
		$('trim-link').show();
	};
	
	/*
	 * Displays and adds functionality to allow 
	 * the user to edit the consensus sequence
	 *
	 */
	phy.change_bases = function(ev) {
		var span = ev.element();

		var current_base = span.getAttribute('base');
		var current_base_position = parseInt(span.getAttribute('position'), 10) + 1;
		var bases = 'ACGT';
		var bases_array;
		
		base_span = new Element('span', {id : 'con'}).update(current_base);
		base_span.addClassName('non-match');
		base_span.addClassName('current-nucleotide');
		
		// allow users to reset any base change back to the original consensus base
		Event.observe(base_span, 'click', function(ev) {
			var span_to_update = $('con' + (current_base_position - 1));
			if (span_to_update && span_to_update.hasClassName('changed-base')) {
				span_to_update.update(current_base);
				span_to_update.removeClassName('changed-base');
				span_to_update.addClassName('non-match');
				
				// reset the change-base-area buttons (remove the red backgrounds)
				// if you click the original consensus base (current_base)
				$$('#change_base_area span.new-nucleotide-option').each(function(el) {
							if (el.hasClassName('changed-base'))
								el.removeClassName('changed-base');
						});
			}
			// Update the Save Changes Button
			phy.prepare_consensus_change();
		});
		
		// Displays the info 'Change Base X at position # to:'
		$('change_base_area').update('Change base ')
					.insert(base_span)
					.insert('&nbsp;at position ' + current_base_position + ' to: ');
					
		
		// Removes the Current Base from the string ATCG and then splits the 
		// remaining string into an array, to be displayed as your selectable 
		// base change options
		bases_array = (bases.replace(current_base, '')).split('');

		bases_array.each(function(b) {
			var base_span = new Element('span', {pos: (current_base_position - 1)}).update(b);
			base_span.addClassName('new-nucleotide-option');
			
			// If you've made a change previously, when you come back, you're
			// change will still be indicated 
			if ($('con' + span.getAttribute('position')).innerHTML == b){
				base_span.addClassName('changed-base');
			}
			
			// If you select another base...
			Event.observe(base_span, 'click', function(ev) {
			
					// Remove the red background from a previously selected base
					$$('#change_base_area span.new-nucleotide-option').each(function(el) {
							if (el.hasClassName('changed-base'))
								el.removeClassName('changed-base');
						});
			
					// Give the newly selected base a red background
					var el = ev.element();
					el.addClassName('changed-base');
					
					// Reflect the base change in the consensus sequence
					var span_to_update = $('con' + el.getAttribute('pos'));
					if (span_to_update) {
						span_to_update.update(el.innerHTML);
						span_to_update.removeClassName('non-match');
						span_to_update.addClassName('changed-base');
					}
					
					// Update the save changes button
					phy.prepare_consensus_change();
						
				});
			$('change_base_area').insert(base_span);
		});
		$('save_changes_btn').show();
		
	};		
	
	/*
	 * Count the number of changes made to the consensus sequence,
	 * inform user of number of changes pending via the save button,
	 * enable the save button if there are any changes to be saved
	 *
	 */
	phy.prepare_consensus_change = function() {
		var changedBaseCount = 0;
		var saveBtnTxt;
		
		// Enable the save changes button
		$('save_changes_btn').enable();
		
		// Count how many changes have been made
		$$('#consensus_div_seq span.changed-base').each(function(el) {
			changedBaseCount++;
		});
		
		// Update the Save Changes button with the number of changes made
		if (changedBaseCount == 1){
			saveBtnTxt = "Save 1 Change";
		}
		else if (changedBaseCount > 1){
			saveBtnTxt = "Save " + changedBaseCount + " Changes";
		}	
		else if (changedBaseCount == 0){
			saveBtnTxt = "Save Changes";
			$('save_changes_btn').disable();
		}
		$('save_changes_btn').value = saveBtnTxt;	
	};
	
	/*
	 * Commits consensus sequence changes made by the user to the database
	 *
	 */
	phy.consensus_change = function () {
		var baseChanges = [];
		
		// Finds all bases in the consensus which have been changed
		// Gets the position and new base and stores these in a hash
		$$('#consensus_div_seq span.changed-base').each(function(el) {
			baseChanges.push([el.getAttribute('position'), el.innerHTML]);
		});

		
		new Ajax.Request('/project/phylogenetics/tools/commit_consensus_changes', {
				method:'get',	
				parameters: {'pair_id': $('pair_id').value, 'base_changes': baseChanges.toJSON()},
				onSuccess: function(transport){
					var response = transport.responseText || "{'status':'error', 'message':'No response'}";
					var r = response.evalJSON();
					if (r.status == 'success') {
						// Update the Save Changes button
						$('save_changes_btn').value = 'Changes Made!';
						$('save_changes_btn').disable();
						
						// Hide the Trace Canvas Div
						//$('trace_canvas_div').hide();
						
						// Hide the change base area div
						//$('change_base_area').hide();
						
						// Update the consensus div (so all BG's are yellow)
						$$('#consensus_div_seq span.changed-base').each(function(el) {
									el.removeClassName('changed-base');
									el.addClassName('non-match');
							});
							
						document.location.reload();
					}
					else {
						alert('Error: ' + r.message);
					}
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
		});
		
	};
	
	/*
	 * View the traces for the mismatched bases in the Consensus Editor
	 * Also calls the function to edit the consensus sequence (phy.change_bases())
	 *
	 */
	phy.view_mismatch_trace = function (ev) {
		var span = ev.element();

		// Show the 'Loading' image
		$('progress').show();
		// Hide the Trace Canvas Div
		$('trace_canvas_div').hide();
		// Hide the Change Bases Area Div
		$('change_base_area').hide();
		// Hide the save button
		$('save_changes_btn').hide();
		
		new Ajax.Request('/project/phylogenetics/tools/consensus_data', {
				method:'get',	
				parameters: {'pair_id': $('pair_id').value, 'pos': span.getAttribute('position')},
				onSuccess: function(transport){
					var response = transport.responseText || "{'status':'error', 'message':'No response'}";
					var data = response.evalJSON();
					if (data) {
						phy.change_bases(ev);
						
						if (data[0])
							phy.draw(data[0], 'trace_viewer_1');
						if (data[1])
							phy.draw(data[1], 'trace_viewer_2');
						
						if (data[0] || data[1]) {
							// Show the Trace Canvas Div
							$('trace_canvas_div').show();
						}

						// Hide the 'Loading' Image
						$('progress').hide();
						// Show the Change Bases Area Div
						$('change_base_area').show();
					}
					else{
					alert('No trace data associated with this sequence');
					}
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
		});
	};
	/*
	 * Activate trim mode in consensus editor
	 *
	 */
	phy.enable_trim = function () {
		// disable mis-match editing
		$$('.non-match').each(function(el) {
			el.removeClassName('non-match');
		});
		$$('.changed-base').each(function(el) {
			el.removeClassName('changed-base');
		});
		$('change_base_area').hide();
		$('trace_canvas_div').hide();
		$('save_changes_btn').hide();
		$$('div span[base]').each(function(element) {
			element.stopObserving();
		});
	
		// enable trimming functions
		$('trim-info').show();
		$('trim-link').hide();
		$('trim-exit-link').show();
		
		// adding class .trim to the 3 sequence divs gives it the 
		// white BG and hover style
		$('consensus_div_seq').addClassName('trim');

		// ----------------
		var spanArray = $$('#consensus_div_seq span');
		var arrayLength = spanArray.length;
		var half = arrayLength / 2;
		spanArray.each(function(el) {
			Event.observe(el, 'click', function(event) {
				var el_o = el;
				var pos = parseInt(el.getAttribute('position'), 10);
				if (pos < half){
					$('left_trim_value').update(pos);
					el.addClassName('to_trim');
					while (el_o.previous()){
						el_o = el_o.previous();
						el_o.addClassName('to_trim');
					}
					var nxt = el.next();
					while (nxt && parseInt(nxt.getAttribute('position'), 10) < half && nxt.hasClassName('to_trim')){
						nxt.removeClassName('to_trim');
						nxt = nxt.next();
						//console.info(nxt.getAttribute('position'));
					}
				}
				else {
					$('right_trim_value').update(arrayLength - pos + 1);
					el.addClassName('to_trim');
					var nxt = el.previous();
					while (nxt && parseInt(nxt.getAttribute('position'), 10) > half && nxt.hasClassName('to_trim')){
						nxt.removeClassName('to_trim');
						nxt = nxt.previous();
						//console.info(nxt.getAttribute('position'));
					}
					while (el_o.next()){
						el_o = el_o.next();
						el_o.addClassName('to_trim');
					}
				}
			});
		});
	};
	/*
	 * Exit trim mode in the consensus editor
	 *
	 */
	phy.exit_trim = function () {
		document.location.reload();
	};
	/*
	 * Commit consus trim changes to DB
	 *
	 */
	phy.commit_consensus_trim = function (pair_id) {
		var left = $('left_trim_value').innerHTML;
		var right = $('right_trim_value').innerHTML;
		var intRegex = /^\d+$/;
		if(!intRegex.test(left) || !intRegex.test(right)) {
			top.show_messages('Invalid trim values specified. Trim values must be positive integers only.');
			return;
		}
		if (left == 0 && right == 0){
			top.show_messages('Nothing to trim');
			return;
		}
		//console.info("pair id: " + pair_id + " | lt: " + left + " | rt: " + right );
		new Ajax.Request('/project/phylogenetics/tools/commit_consensus_trimming', {
			method:'get',	
			parameters: {'pair_id': pair_id, 'left': left, 'right': right},
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r.status == 'success') {
					document.location.reload();
					//console.info('100');
				}
				else {
					top.show_messages('Error: ' + r.message);
				}
			},
			onFailure: function(){					
				alert('Something went wrong!\nAborting...');
			}
		});	
	}
	
	/*
	 * Reset the trim in the consensus editor
	 *
	 */
	phy.reset_consensus_trim = function (dir) {
		var spanArray = $$('#consensus_div_seq.trim span');
		var arrayLength = spanArray.length;
		var half = arrayLength / 2;
		var elArray = $$('#consensus_div_seq.trim span.to_trim');
		if (dir == 'l' || dir == 'left'){
			$('left_trim_value').update('0');
			elArray.each(function(el) {
				var pos = parseInt(el.getAttribute('position'), 10);
				if (pos < half){
					el.removeClassName('to_trim');
				}
			});
		}
		if (dir == 'r' || dir == 'right'){
			$('right_trim_value').update('0');
			elArray.each(function(el) {
				var pos = parseInt(el.getAttribute('position'), 10);
				if (pos > half){
					el.removeClassName('to_trim');
				}
			});
		}
	};
	
	/*
	 * Edit the name of the pair in the consensus editor
	 *
	 */
	phy.edit_pair_name = function () {
		$('pair-title').toggle();
		$('edit-pair-title').toggle();
		$('edit-name-link').toggle();
		$('save-name-link').toggle();
	};
	/*
	 * Save the name of the pair in the database after changing it in the consensus editor
	 *
	 */
	phy.save_pair_name = function (name, num, pair_id) {
		if (name == ''){
			top.show_messages('Enter a name for your pair');
			return;
		}
		if (name.length > 128){
			top.show_messages('Pair name must be less than 128 characters');
			return;
		}
		var regex = /[^-_.\w\d]/;
		if (regex.exec(name)){
			top.show_messages('Pair names can only contain letters, numbers, periods, dashes, and underscores. Spaces and special characters are not allowed.');
			return;
		}
		new Ajax.Request('/project/phylogenetics/tools/save_pair_name', {
			method:'get',	
			parameters: {'pair_id': pair_id, 'name': name},
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r.status == 'success') {
					$('pair-title').update('Pair ' + num + ': ' + name);
					$('edit-pair-title').toggle();
					$('pair-title').toggle();
					$('edit-name-link').toggle();
					$('save-name-link').toggle();
					$$('div.pair-id-block.active small').each(function(el) {
						el.update(name);
					});
					$$('.pair-id-block.active').each(function(el){
						el.title=name;
					});
				}
				else {
					top.show_messages('Error: ' + r.message);
				}
			},
			onFailure: function(){					
				alert('Something went wrong!\nAborting...');
			}
		});		
	};
	
	

	phy.add_data = function () {
		var seq_src = $$('input[type="radio"]').find(function(el){
			return el.checked == true
		});
		debug(seq_src.value);
		if (seq_src.value == "upload") {
			if ($('seq_file').value == "") {
				alert("Select a file to upload.");
				return;
			}
		}
		else if (seq_src.value == "paste") {
			if ($('sequence').value == "") {
				alert("Sequence is missing.");
				$('sequence').focus();
				return;
			}
		}
		$('forma1').submit();
	};
	// -----------------------------------------------
	// handlers for getting dnalc data
	//
	phy.get_dnalc_data = function (page, order_id, sort_by, sort_dir, query, get_all_data) {
		$('add_btn').hide();
		var apiUri = "http://dnalc02.cshl.edu/genewiz/json";
		var uri = apiUri + "?p=" + (page ? page : 1);
		if (order_id) {
			if (/^\d+$/.test(order_id)) {
				uri += ";o=" + order_id;
				if (query) {
					uri += ";q=" + query;
				}
			}
			else {
				if (order_id.length < 4) {
					try {
						top.show_messages("Search query is too short!");
					} catch(err) {};
					return;
				}
				else {
					uri += ";q=" + order_id;
				}
			}
		}
		
		if (sort_by) {
			uri += ";s=" + sort_by;
			if (sort_dir)
				uri += ";d=" + sort_dir;
		}

		// by default apply the filters, unless otherwise specified
		if (!get_all_data) {
			if (top.$('ptype') && top.$('ptype').value) {
				uri += ";f=" + top.$('ptype').value;
			}
			else {
				var f = top.$$('div#project_types input[type=radio]').collect(function(v){return v.checked ? v.value: ''}).join('');
				if (f) {
					uri += ";f=" + f;
				}
			}
		}

		if ($('dnalc_btn'))
			$('dnalc_btn').remove();

		var elem = $('dnalc_provider');
		if (elem)
			elem.remove();
		elem = new Element('script', {src: uri, title: 'text/javascript', id: 'dnalc_provider'});
		$$('head').first().insert(elem);

		$('progress_bar').hide();
	};
	
	phy.parse_dnalc_data = function(meta, data) {
		if (meta.t == 'l') { // list
			phy.display_dnalc_data(meta, data);
		}
		else if (meta.t == 'o') { // order details
			phy.display_dnalc_files(meta, data);
		}
	};
	
	phy.display_dnalc_data = function(meta, data) {
		var table = new Element('table');
		var tr;
		if (Object.isArray(data)) {
			tr = phy.build_tr(["Tracking #", "Date", "Name", "Institution"], 'header', meta);
			// adjust cells' width
			tr.cells[2].addClassName("twenty5p");
			tr.cells[3].addClassName("forty5p");
			table.insert(tr);
			data.each(function(d) {
				var lnk = new Element('a', {href: 'javascript:;'}).update(d.number);
				Event.observe(lnk, 'click', function() {phy.get_dnalc_data(meta.p, d.id, meta.s, meta.d, meta.q, meta.f ? '' : '1');});
				tr = phy.build_tr([lnk, d.date, d.name, d.institution]);
				table.insert(tr);
			});
		}

		if (meta.pnum > 1) {
			var nav = "";
			var query = meta.q ? meta.q : '';
			var args = ",'" + query + "','" + meta.s + "','" +meta.d + "',null,'" + (meta.f ? '' : '1') + "'";
			if (meta.p > 1) {
				nav += "<a href=\"javascript:phy.get_dnalc_data(" + (meta.p - 1) + args + ");\">«</a> ";
			}
			nav += "Page " + meta.p + " of " + meta.pnum;
			if (meta.p < meta.pnum) {
				nav += " <a href=\"javascript:phy.get_dnalc_data(" + (meta.p + 1) + args + ");\">»</a> ";
			}
			//tr = phy.build_tr([nav]);
			//tr.cells[0].colspan = "3";
			table.insert("<tr><td colspan=\"3\">" + nav + "</td></tr>");
		}
		
		var filters = 	meta.f  
				? "<div id=\"filters\" style=\"float:right\">"
					+   "Showing orders containing <b>" + meta.f.toUpperCase() + "</b> samples. "
					+   "<a onclick=\"javascript:phy.get_dnalc_data(null, null, null, null, null, 1);this.hide();\""
					+     " href=\"javascript:;\">show all</a>"
					+ "</div>"
				: "";
		$('dnalc_container').update(
			new Element('div', {style: 'width: 760px'}).update(
				filters
			).insert(
				new Element('input', {id:'q', value:meta.q, type:'search'})
					.observe('keydown', function(ev) { // catch the ENTER hit in the input box
						if (ev && ev.keyCode == 13) {
							phy.get_dnalc_data(1, $('q').value, meta.s, meta.d, null, 1);
						}
					})
			).insert(new Element('input', {type: 'button', value:'Search', 'class': 'bluebtn'})
				.observe('click', function(){
					phy.get_dnalc_data(1, $('q').value, meta.s, meta.d, null, 1);
				})
			)
		);
		$('dnalc_container').insert(table);
	};
	phy.display_dnalc_files = function(meta, data) {
		var table = new Element('table');
		var a = new Element('a', {href:'javascript:;'}).update('« back');
		a.observe('click', function(){ phy.get_dnalc_data(meta.p, meta.q ? meta.q : null, meta.s, meta.d, null, meta.f ? null : '1') });

		var tr = phy.build_tr([a, '']);
		table.insert(tr);
		
		['number', 'name', 'institution'].each(function(el) {
			tr = phy.build_tr([el + ':', data[el]], 'ucfirst');
			table.insert(tr);
		});
		if (data.files && data.files.length) {
			var fall = new Element('input', {type: 'checkbox', id: 'files_all'});
			a  = new Element('a', {href:'javascript:;', id: 's_alla', style: 'padding-left: 6px;'}).update('select all');
			var f = new Element('div', {id: 'order_files'}).insert(new Element('div').insert(fall).insert(a));
			var file_divs = [f];
			if (data.files.length >=  16) {
				var h1 = new Element('div', {'class': 'halfdiv'});
				var h2 = new Element('div', {'class': 'halfdiv'});
				f.insert(h1);
				f.insert(h2);
				file_divs = [h1, h2	];
			}

			fall.observe('click', function(){ phy.select_all_dnalc_files() });
			a.observe('click', function(){ phy.select_all_dnalc_files(true) });
			
			data.files.each(function(el, i) {
				var hdiv = file_divs.length == 2 && i >= data.files.length/2 ? 1 : 0;
				var chk = new Element('input', {type: 'checkbox', value: el.id});
				chk.observe('change', function(ev){ 
								if (!ev.element.checked)
									fall.checked = false;
								phy.check_selection_dnalc_files();
						});
				var img = '';
				if (el.qs != null) {
					var iqs = parseInt(el.qs, 10);
					if (!isNaN(iqs) && iqs > 0 && iqs < 20) {
						img = new Element('img', {src :'/images/chart_curve_error.png', title: 'QScore = ' + el.qs});
					}
				}

				file_divs[hdiv].insert(new Element('div')
					.insert(chk )
					.insert(new Element('span').update(' ' + el.file + ' '))
					.insert(img)
				);
				
			});
			tr = phy.build_tr(['Files:', f], 'vtop');
			table.insert(tr);
		}
		$('dnalc_container').update(table);
		$('dnalc_container').insert(new Element('input', {type: 'hidden', value: meta.o, id: 'oid'}));
	};
	phy.build_tr = function(data, _class, meta) {
		var tr = new Element('tr');
		if (_class)
			tr.addClassName(_class);
		data.each(function(el, i) {
			if (meta && _class == "header") {
				var query = meta.q ? meta.q.replace(/'/g, '\'') : '';
				var ch = el.toLowerCase().substring(0,1);
				// unicode arrows from http://www.fileformat.info/info/unicode/block/arrows/utf8test.htm
				if (ch == meta.s && 'a' == meta.d) {
					el += " ⇧";
				}
				else if (ch != meta.s || 'a' != meta.d) {
					el += " <a href=\"javascript:phy.get_dnalc_data(1,'" + query + "','" + ch + "','a',null," + (meta.f ? 'null' : '1') + ");\">⇧</a>";
				}
				if (ch == meta.s && 'd' == meta.d) {
					el += " ⇩";
				}
				else if (ch != meta.s || 'd' != meta.d) {
					el += " <a href=\"javascript:phy.get_dnalc_data(1,'" + query + "','" + ch + "','d',null," + (meta.f ? 'null' : '1') + ");\">⇩</a>";
				}
			}
			tr.insert(new Element('td').update(el));
		});
		return tr;
	};
	
	phy.select_all_dnalc_files = function (from_a) {
		var fall = $('files_all');
		if (from_a) {
			fall.checked = !fall.checked;
		}
		var all = fall.checked;
		$$('div#order_files input[type=checkbox]').each(function(el) {
			if (!/all/.test(el.id))
				el.checked = all;
		});
		if (fall.checked) 
			$('s_alla').update('unselect all');
		else
			$('s_alla').update('select all');
		phy.check_selection_dnalc_files();
	};
	
	phy.check_selection_dnalc_files = function () {
		var ids = [];
		$$('div#order_files input[type=checkbox]').each(function(el) {
			if (el.checked && !el.id)
				ids.push(el.value);
		});
		if (ids.length) {
			$('add_btn').style.display = 'block';
		}
		else {
			$('add_btn').style.display = 'none';
		}
		return ids;
	};
	
	phy.get_dnalc_files = function () {
		var oid = $('oid')? $('oid').value : null;
		if (!oid)
			return;
		var ids = phy.check_selection_dnalc_files();
		var data = {oid: oid, ids: ids};
		debug(Object.toJSON(data));
		new Ajax.Request('/project/phylogenetics/tools/dnalc_request_transfer', {
				method:'get',	
				parameters: data,
				onSuccess: function(transport){
					var response = transport.responseText || "{'status':'error', 'message':'No response'}";
					debug(response);
					var r = response.evalJSON();
					if (r.h && r.d) {
						phy.check_dnalc_transfer(r.h, r.d);
						$('add_btn').hide();
						$('progress_bar').style.display = 'block';
					}
					else {
						alert('Error: ' + 'something went wrong.');
					}
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
		});
	};
	phy.check_dnalc_transfer = function (h, d) {
		var prev_p = 1;
		new PeriodicalExecuter(function(pe) {
			new Ajax.Request('/project/phylogenetics/tools/dnalc_check_transfer', {
				method:'get',	
				parameters: {h: h, d: d},
				onSuccess: function(transport){
					var response = transport.responseText || "{'status':'error', 'message':'No response'}";
					var r = response.evalJSON();
					//debug(r);
					if (r.error || (r.known == 0 && r.running == 0 || r.percent == 100)) {
						pe.stop();
						if (prev_p > 1 || r.percent == 100) {
							phy.update_progress_bar(100);
							phy.finish_dnalc_transfer(d, $('pid').value);
						}
					}
					else {
						phy.update_progress_bar(r.percent);
						prev_p = r.percent;
					}
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
			});
		}, 3);
	};
	phy.update_progress_bar = function(p) {
		if (p < 2)
			p = 2;
		$$('div.ui-progress')[0].style.width = p + '%';
		$$('div.ui-progress span.ui-label')[0].show()
		$$('div.ui-progress b.value')[0].update(p + '%');
	};
	phy.finish_dnalc_transfer = function(d, pid) {
		var f;
		if (pid == 'new') {
			f = $(parent.document.getElementById('forma1'));
			f.insert(new Element('input', {type: 'hidden', name: 'data_transfered', value: 'dnalc'}));
		}
		else {
			f = new Element('form');
			f.action = "/project/phylogenetics/tools/add_data";
			f.method = "post";
			f.insert(new Element('input', {type: 'hidden', name: 'pid', value: pid}));
			f.insert(new Element('input', {type: 'hidden', name: 'seq_src', value: 'dnalc'}));
			
			$('dnalc_container').insert(f);
		}
		f.insert(new Element('input', {type: 'hidden', name: 'd', value: d}));
		f.submit();
	};
	phy.addAuthor = function(num, action){
		if (action == 'remove'){
				$('row' + num).remove();
		}
		else{
			num++;
			$('new_row').replace('<tr id="row' + num + '" class="author_row"><td>Collector/Author</td><td>&nbsp;&nbsp;<input class="fb" type="text" style="width:145px" id="collector_first_" name="collector_first_" value="First Name" onfocus="if(this.value==\'First Name\'){this.value=\'\'};" onblur="if(this.value==\'\'){this.value=\'First Name\'};"/>&nbsp;<input class="fb" type="text" style="width:145px" id="collector_last_" name="collector_last_" value="Last Name" onfocus="if(this.value==\'Last Name\'){this.value=\'\'};" onblur="if(this.value==\'\'){this.value=\'Last Name\'};"/> <span><a href="javascript:;" onclick="phy.addAuthor(' + num + ', \'remove\')" style="text-decoration:none;font-weight:bold;color:black"><img src="/images/minus.jpg" border=0 width="12px" height="12px" />  Remove</a></span></td></tr><tr id="new_row"></tr>');
			$('add_author_link1').update('<a href="javascript:;" onclick="phy.addAuthor(' + num + ');" style="text-decoration:none;font-weight:bold;color:black"> <img src="/images/plus.jpg" border=0 width="12px" height="12px" /> Add Another</a>');
		}
	}
	phy.collect_authors = function(){
		var firstNames = [];
		var lastNames = [];
		var fullNames = "";
		$$('tr[class="author_row"]').each(function(e){
			e.descendants().each(function(el){
				if (el.id.indexOf("collector_first") == 0) {
					//console.info(el.value);
					firstNames.push(el.value);
				}
				if (el.id.indexOf("collector_last") == 0) {
					lastNames.push(el.value);
				}
			});
		});
		for (var i = 0; i < lastNames.length; i++){
			fullNames = fullNames + firstNames[i] + "#" + lastNames[i] + "#" + (i + 1) + "::";
		}
		//console.info(fullNames);
		$('new_row').update('<input type="hidden" id="authors" name="authors" value="' + fullNames + '" />');
	}
	
	phy.collect_primer_data = function() {
		var f_primer = $('f_primer').value;
		var r_primer = $('r_primer').value;
		$('new_row').insert('<input type="hidden" id="r_primer_set" name="r_primer_set" value="' + r_primer + '" /><input type="hidden" id="f_primer_set" name="f_primer_set" value="' + f_primer + '" />');
	}
	//----------------------------------------------------
	//
	phy.setColumnWidths = function(w) {
		var idsWidth = $('seqids').getWidth();
		var seqsWidth = w - idsWidth -9;
		$('seqs').setStyle({
			width: seqsWidth + 'px',
			display: 'block'
		});
	}

	//----------------------------------------------------
	phy.show_ref_details = function(ref_id) {
		$('ref_details').update($('rd' + ref_id).innerHTML);
	};
	//----------------------------------------------------
	phy.prev_bold_step = function() {
		var f = $('bform');
		var s = 1;
		var m = f.action.match(/\d/);
		if (m) {
			s = parseInt(m[0], 10);
			if (isNaN(s))
				return;
			else
				s = s - 1;
		}
		if (s > 0)
			document.location.replace("./step" + s + ".html");
	};

	phy.next_bold_step = function() {
		var f = $('bform');
		f.submit();
	};
	//----------------------------------------------------
	
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
	var step = document.getElementById('step') != null ? parseInt(document.getElementById('step').value, 10) : 0;
	debug("step = " + step);
	
	if (step == -1) {
		var type_chosen = false;
		$$('#project_types input[type=radio]').each(function(el) {
			Event.observe(el, 'click', function(ev){
				//debug('clicked ' + el.value);
				phy.type_chosen_handler(el.value);
			});
			if (!type_chosen && el.checked)
				type_chosen = true;
			
			$$('input[name=seq_src]').each(function(el) {
				el.disabled = !type_chosen;
			});
			//debug();
		});
	}
	// Step 1 : Pair Builder
	else if (step == 1) {
		$('seqops').down().descendants().each(function(sp){
		  if (sp.type && sp.type == "checkbox") {
			Event.observe(sp, 'click', function(ev){
				var el = Event.element(ev);
				//el.checked = false;
				var id = el.id.replace(/^op/,'');
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
				if (a_rc && a_rc.innerHTML == "R") {
					phy.toggle_strand(a_rc, 1);
				}
				$('op' + el).disable();
				$('op' + el).hide();
			});
		});
		if ($('do_pair') != null)
			$('do_pair').disabled = true;
			
		// Set column widths and display columns
		phy.setColumnWidths(560);
		$('seqops').style.display = 'block';
		$('seqops2').style.display = 'block';
	
	}
	
	// step 22 is from the sequence viewer before you select a trace to view
	else if (step == 22) {
		// attach tool tip for low quality score alerts
		$$('#mini-trace-icons div[id^=low]').each(function(el) {
			var span_id = el.getAttribute('id');
			debug("tip " + span_id);
			new Tip(span_id, "The average error rate for this sequence is greater than 1%. This indicates that the sequence is of low quality and may produce erroneous analysis results.", {
				title: "Low Quality Score Alert",
				style: 'blue',
				showOn: 'mouseover',
				//hideOn: { element: 'closeButton', event: 'click' },
				hideOthers: true
			});
		});	
		// Set column widths and display columns
		phy.setColumnWidths(795);
	}
	
	// step 2 is from the sequence viewer, once you select a trace file to view
	else if (step == 2) {
		// attach tool tip for low quality score alerts
		$$('#mini-trace-icons span[id^=low]').each(function(el) {
			var span_id = el.getAttribute('id');
			debug("tip " + span_id);
			new Tip(span_id, "The average error rate for this sequence is greater than 1%. This indicates that the sequence is of low quality and may produce erroneous analysis results.", {
				title: "Low Quality Score Alert",
				style: 'blue',
				showOn: 'mouseover',
				//hideOn: 'click',
				//hideOn: { element: 'closeButton', event: 'click' },
				hideOthers: true
			});
		});	
		
		var ua = navigator.userAgent.match(/MSIE\s+(\d+)/);
		if (ua && ua.length > 1 && parseInt(ua[1], 10) < 9) {
			phy.zoomIn('x');
		}

		phy.prepare_draw();
		
		if (ua && ua.length > 1 && parseInt(ua[1], 10) < 9) {
			//phy.zoomIn('x');
			setTimeout("phy.zoomOut('x')", 100);
		}
		
		// Set column widths and display columns
		phy.setColumnWidths(795);
		
	}
	else if (step == 3) {
		/*
		$$('div[id^=tip]').each(function(el){
			new Tip(el.id, 
				el.getAttribute('desc'),
			{
				title : el.innerHTML,
				style: 'blue'
			});
			$(el.id).observe('prototip:shown', function(event) {
				//this.pulsate({ pulses: 1, duration: 0.3 });
				//event.inner
				phy.get_ggl_image(el);
			});
		});
		*/
	}
	else if (step == 4) {
		var pre = pre=$('alignment').down();

		var sz = parseInt($('alignment_length').value, 0);
		var pre=$('alignment').down();
		var spn = new Element('span');
		$R(0, sz, true).each(function(val) {
			if (val % 10 == 0) {
				spn.insert(new Element('span').update(val));
				spn.addClassName('rot');
				//debug(val);
			}
			else
				spn.insert(new Element('span').update(' '));
		});

		pre.insert({top:spn});
		/*
		//insert(element, { position: content }) -> HTMLElement
// insert(element, content) -> HTMLElement
sz = parseInt($('alignment_length').value, 0);
pre=$('alignment').down();
spn = new Element('span');
$R(0, sz, true).each(function(val) {
  if (val % 10 == 0)
    spn.insert(new Element('span', {class:'rot'}).update(val));
  else
    spn.insert(new Element('span').update(' '));
});

pre.insert({top:spn});

		*/
	}
	
	/*
	 * Consensus Editor
	 *
	 */
	else if (step == 5) {
		phy.show_mismatches();
	}
	else if (step == 7) {
		phy.get_dnalc_data();
	}
	else if (step == 8) {
		phy.setColumnWidths(700);
		$('seqops').style.display = 'block';
	}
	
   /*
	* Submit to GenBank steps below
	*
	*/
	else if (step == 30){
		var num = $('num').value;
		$('add_author_link1').update('<a href="javascript:;" onclick="phy.addAuthor(' + num + ');" style="text-decoration:none;font-weight:bold;color:black"> <img src="/images/plus.jpg" border=0 width="12px" height="12px" /> Add Another</a>');
	}
	
	
});
