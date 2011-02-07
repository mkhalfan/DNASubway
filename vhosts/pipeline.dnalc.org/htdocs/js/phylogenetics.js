	var pairs = [];
	var current_pair = [];
	var intervalID = {};
	var xZoom = 1;
	var yZoom = 1;
	var yLimit = 80; // max y a trace can have, so the graph stays in the canvas
	
	var _dbg;
(function() {
	// keeps open windows
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

		if (! $('seq_src_upload').checked && !$('seq_src_paste').checked && !$('seq_src_sample').checked) {
			//alert("Source not selected!");
			show_messages("Sequence source not selected!");
			return;
		}

		var has_file = $('seq_src_upload').checked && ( $('seq_file').value != '' );
		//var has_sample = $('seq_src_sample').checked && $('specie').selectedIndex != -1;
		var has_actg = false;
		var has_sample = $('seq_src_sample').checked && $('sample').selectedIndex >= 0;

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

		if (!has_file && !has_actg && !has_sample) {
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
	
	phy.select_source = function (el) {
		return;
		//debug(el);
		debug($$('#' + el + '_inputs, #' + el + '_inputs textarea'));
		debug($$('#' + el + '_inputs, #' + el + '_inputs input'));
		if (el && (el == 'upload' || el == 'paste')) {
			//$('specie').selectedIndex = -1;
		}
		else if (el && el == 'sample') {
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
				viewer: ['/project/phylogenetics/tools/view_sequences.html?pid=', 'Sequence Viewer'],
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
						if ($(windows[what].content.down().contentWindow.document).getElementById('selection_changed').value != "") {
							if (!confirm("You haven't saved your selection.\nDo you really want to close this window?")) {
								return false;
							}
						}
						windows[what].destroy(); 
						return true;
					}
				}
			};
		}
		
		windows[what] = openWindow( uri, window_title, options);
		
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

					[0,1].each(function(k) {
						$(pairs[i][k]).removeClassName('bold');
						$(pairs[i][k]).removeClassName('paired-light');
						$(pairs[i][k]).removeClassName('paired-dark');
						$('op' + pairs[i][k]).checked = false;
					});
					delete pairs[i];
					pairs = pairs.compact();
					throw $break;
				}
			}
		}
		if ($('do_pair') != null && $('do_pair').disabled) {
			$('do_pair').disabled = false;
		}
	};
	
	phy.run = function(op, params) {
		//var s = $(op);
		var b = $(op + '_btn');
		var p = $('pid').value;
		var ind = $(op + '_st');

		var delay = b ? parseFloat(b.getAttribute('delay')) : 10;
		delay = !isNaN(delay) ? (delay * 1000) : 10000;

		new Ajax.Request('/project/phylogenetics/launch_job',{
			method:'get',
			parameters: { 't' : op, pid : p, params: params}, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				debug(response);
				var r = response.evalJSON();
				//dbg = r;
				//alert('after launch job:\n' + response + ' ' + r.h);
				if (r.status == 'success') {
					var h = r.h || '';
					//intervalID[op] = setInterval(function (){ phy.check_status(p, op, h)}, delay);
					
				}
				else  if (r.status == 'error') {
					show_errors(r.message);
				}
				else {
					//s.update('Unknown status!');
					alert('Unknown status!');
				}
			},
			onFailure: function(){
					alert('Something went wrong!\nAborting...');
				}
		});
	};
	
	phy.toggle_strand = function(el, norclbl) {
		//debug(el);
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

		//debug(lpairs.toJSON());
		
		if (lpairs.length == 0)
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
					phy.launch(op, '/project/phylogenetics/tools/' + uri + '?pid=' + p, '');
				};
		}
		else if (status == 'not-processed') {
			ind.removeClassName(ind.className);
			ind.addClassName('conIndicatorBL_not-processed');
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
		new Ajax.Request('/project/phylogenetics/tools/' + uri,{
			method:'get',
			parameters: { 't' : op, pid : p}, 
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				//debug(response);
				var r = response.evalJSON();
				//debug(r);
		
				if (r.status == 'success') {
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
			debug("change status if it's the case....");
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
			//var str = "NNNNNNNTGNATCAGCTGGTGTTAAGATTACAAATTGACTTATTATACTCCTGAGTATGACCCCGCGGATACTGATATCTTGGCAGCATTCCGAGTAACTCCTCAACCTGGAGTTCCGCCGGAAGAAGCAGGGGCCGCGGTAGCTGCCGAATCTTCTACTGG";
			// var qual = [3,2,4,3,3,4,4,6,6,4,5,11,7,8,7,9,30,19,33,15,37,33,11,13,13,12,12,10,31,30,34,21,41,47,52,53,53,31,32,57,53,52,40,47,61,50,53,61,61,61,50,61,61,47,47,61,35,38,61,55,55,61,61,61,61,61,61,61,38,38,49,49,61,61,47,61,55,49,61,61,61,36,18,14,12,19,19,61,61,61,61,61,61,61,61,59,61,61,61,61,59,55,55,59,61,61,61,61,61,61,55,59,61,61,61,59,61,61,61,61,61,61,59,61,59,61,59,59,59,59,59,55,59,61,61,55,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,61,55,59,59,61,61,61,61,61];
			var qual = [];
			var str  = $('seq_data').value;
			var qval = $('qvalues').value;
			debug(str.length);
			qval.split(',').each(function(q){
					//debug(q);
					qual.push(parseInt(q, 10));
				});
			debug(str.length + " " + qual.length);
			
			// get text's size and resize the canvas
			ctx.font = font;
			ctx.fillStyle = "Black";
			var metrics = ctx.measureText(str);
			var text_width = metrics.width;
			canvas.width = text_width + 2*padding;

			var char_width = text_width/str.length;
			debug(text_width + " " + char_width);
			
			
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
		var sequence = $('seq_data').value;
		var baseLocations = [];
		var qualityScores = [];
		var display_id = $('seq_display_id').value;
		
		var traces = {};
		//var str  = $('seq_data').value;
		var qval = $('qvalues').value;
		//debug(str.length);
		qval.split(',').each(function(q){
				qualityScores.push(parseInt(q, 10));
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
		var lastBase = Math.max.apply(Math, baseLocationsPositions);
		var ctx = canvas.getContext('2d');
		
		var title = data['seq_display_id'];
		var sequence = data['sequence'];
		var qualityScores = data['qscores'];
		var baseLocations = data['base_locations']; // The position of the base in the entire sequence
		var baseLocationsPositions = []; // The position of the base on the canvas (in our subsequence)
		
		// Normalize the base locations to baseLocationsPositions
		for (var b = 0; b < baseLocations.length; b++){
			baseLocationsPositions[b] = baseLocations[b] - baseLocations[0];
		}
		
		// Calculate the width of the canvas 
		// If it's the consensus editor, make it the width of the Display ID.
		// If it's the View Sequences (entire sequence), make it the width of the entire sequence.
		// ('seq_id' is only passed from the consensus editor - that's how we check)
		if (data['seq_id']){
			canvas.width = ctx.measureText(title).width + 4 + padding;
		}
		else {
			canvas.width = lastBase * xZoom + 15;
		}
		
				
		function drawTrace(n, color){
			ctx.strokeStyle = color;
			ctx.beginPath();		
			ctx.moveTo(padding, height - padding);
			n.each(function(x, i) {
				var y = height - padding - x * yZoom;
				
				if (y < yLimit){
					y = yLimit;
				}
				
				ctx.lineTo(padding + i * xZoom, y);
			});
			ctx.stroke();
			ctx.closePath();
		}
		
		drawTrace(data['trace_values']['A'], "green");
		drawTrace(data['trace_values']['T'], "red");
		drawTrace(data['trace_values']['C'], "blue");
		drawTrace(data['trace_values']['G'], "black");

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
				if (i%10 == 0){
					ctx.fillStyle = "black";
					ctx.fillText(i, padding + bl * xZoom - 3, baseLocationYPos);
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

		baseLocationsPositions.each(function(bl, i) {
			ctx.fillRect(
					padding + bl * xZoom, qualScoreYPos - qualityScores[i]/4, 
					nucleotideWidth, qualityScores[i]/4
				);
		});
		
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
					}
					else {
						$$("#seqops pre")[0].show();
						$("seqops").removeClassName('blast_processing');
						alert("Some error occured " + r.message);	
					}
				}
				else {
					//debug(show_messages);
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
		//top.phy.close_window('blast');
		//return;
		new Ajax.Request('/project/phylogenetics/tools/add_blast_data',{
			method:'post',
			parameters: { bid : bid, pid: $('pid').value},
			onSuccess: function(transport){
				var response = transport.responseText || "{'status':'error', 'message':'No response'}";
				var r = response.evalJSON();
				if (r && r.status == 'success') {
					top.phy.set_status('phy_alignment', 'not-processed');
					top.phy.close_window('blast');
				}
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
								new Element('a', {href: d['link']}).update(d['title'])
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
		//debug(query);
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
				//debug(str.length + ' ' + aln_length);
				if (str.length > 0 && str.length != aln_length) {
					trimmed = true;
					//return;
				}
			});
			//debug('trimmed: ' + trimmed);
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
		var cd = "";
		var re = /[N-]/;

		var sequenceLength = consensus.length;
		var consensus_span, seq1_span, seq2_span;
		
		$('seq1_name').update(display_name_1);
		$('seq2_name').update(display_name_2);
		$('consensus_div_name').update("Consensus");
		
		for ( var i = 0; i < sequenceLength; i++){
			//console.debug(i + "\t" + consensus.charAt(i) + " = " + seq2.charAt(i) + " + " + seq1.charAt(i) );
			if ( !re.test(seq1.charAt(i)) && !re.test(seq2.charAt(i)) 
					&& (consensus.charAt(i) != seq1.charAt(i) || consensus.charAt(i) != seq2.charAt(i) )
				) 
			{
				//temp = "<span class='non-match'>" + consensus.charAt(i) + "</span>";
				//span = new Element('span', {class: 'non-match', 'position': i, 'base': consensus.charAt(i)}).update(consensus.charAt(i));
				consensus_span = new Element('span', {id: 'con' + i, 'position': i, 'base': consensus.charAt(i)}).update(consensus.charAt(i));
				seq1_span = new Element('span', {'position': i, 'base': consensus.charAt(i)}).update(seq1.charAt(i));
				seq2_span = new Element('span', {'position': i, 'base': consensus.charAt(i)}).update(seq2.charAt(i));
				
				seq1_span.addClassName('non-match');
				seq2_span.addClassName('non-match');
				consensus_span.addClassName('non-match');
				
				Event.observe(consensus_span, 'click', phy.view_mismatch_trace);
				Event.observe(seq1_span, 'click', phy.view_mismatch_trace);
				Event.observe(seq2_span, 'click', phy.view_mismatch_trace);
				
			}
			else{
				//temp = "<span>" + consensus.charAt(i) + "</span>";
				consensus_span = new Element('span').update(consensus.charAt(i));
				seq1_span = new Element('span').update(seq1.charAt(i));
				seq2_span = new Element('span').update(seq2.charAt(i));
			}
			//cd += temp;
			$('consensus_div_seq').insert(consensus_span);
			$('seq1_div').insert(seq1_span);
			$('seq2_div').insert(seq2_span);
			
			// Initially, set the save_changes_button to be disabled
			$('save_changes_btn').disabled = true;
		} 
	}
	
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
		$('change_base_area').update('Change Base ')
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
					
					// Updatet he save changes button
					phy.prepare_consensus_change();
						
				});
			$('change_base_area').insert(base_span);
		});
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
	}
	
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
		console.info(baseChanges.toJSON());
		
		new Ajax.Request('/project/phylogenetics/tools/commit_consensus_changes', {
				method:'get',	
				parameters: {'pair_id': $('pair_id').value, 'base_changes': baseChanges.toJSON()},
				onSuccess: function(){
					// Update the Save Changes button
					$('save_changes_btn').value = 'Changes Made';
					$('save_changes_btn').disable();
					
					// Hide the Trace Canvas Div
					$('trace_canvas_div').hide();
					
					// Update the consensus div (so all BG's are yellow)
					$$('#consensus_div_seq span.changed-base').each(function(el) {
								el.removeClassName('changed-base');
								el.addClassName('non-match');
						});
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
		});
		
	}
	
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
		
		new Ajax.Request('/project/phylogenetics/tools/consensus_data', {
				method:'get',	
				parameters: {'pair_id': $('pair_id').value, 'pos': span.getAttribute('position')},
				onSuccess: function(transport){
					var response = transport.responseText || "{'status':'error', 'message':'No response'}";
					var data = response.evalJSON();
					//debug(response);
					if (data) {
						
						phy.change_bases(ev);

						phy.draw(data[0], 'trace_viewer_1');
						phy.draw(data[1], 'trace_viewer_2');
						
						// Show the Trace Canvas Div
						$('trace_canvas_div').show();
						// Hide the 'Loading' Image
						$('progress').hide();
					}
				},
				onFailure: function(){
						alert('Something went wrong!\nAborting...');
					}
		});
	}
	

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
		$$('#project_types input[type=radio]').each(function(el) {
			Event.observe(el, 'click', function(ev){
				//debug('clicked ' + el.value);
				phy.get_samples(el.value);
			});
		});
	}
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
			});
		});
		if ($('do_pair') != null)
			$('do_pair').disabled = true;
	}
	else if (step == 2) {
		//alert(step);
		//phy.draw_qvalues();
		phy.prepare_draw();
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
		debug(pre.down());

		var sz = parseInt($('alignment_length').value, 0);
		debug(sz);
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
	
	
});
