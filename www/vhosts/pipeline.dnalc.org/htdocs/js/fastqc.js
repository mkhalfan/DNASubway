/* A script to shrink the FastQC report */

function shrinkQC () {
	// get all image reports and make them smaller
	var images = $$('img.indented');
 	for (var i=0; i<images.length; i++) {
		images[i].setStyle({width: '450px'});
	}

	// h2s a bit less garish
	var h2 = $$('h2');
	for (var i=0; i<h2.length; i++) {
		h2[i].setStyle({fontSize: '14pt'});
	}

	// tables headers a bit smaller
	var th = $$('th');
	for (var i=0; i<th.length; i++) {
		th[i].setStyle({fontSize: '9pt'});
	}

	// monospaced tabe cells a bit smaller
	var td = $$('td');
	for (var i=0; i<td.length; i++)	{
                td[i].setStyle({fontSize: '8pt'});
	}

	// make the navbar links a bit smaller
	var li = $$('li');
	for (var i=0; i<li.length; i++)	{
		li[i].setStyle({fontSize: '10pt'});
	}

	// make the icons a bit smaller
	var img = $$('img');
	for (var i=0; i<img.length; i++)	{
		if (img[i].src.match('Icon')) {
			img[i].setStyle({width: '20px'});
		}
	}

	// scrunch up the reports a bit
	var modules = $$('div.module');
	for (var i=0; i<modules.length; i++) {
                modules[i].setStyle({paddingBottom: '0'});
        }

	// header a bit less ostentatious
	$$('div.header')[0].setStyle({fontSize: 'large', padding: '0.2em'});
	
	// adjust the panels
	$$('div.main')[0].setStyle({top: '1.8em', left: '14em'});
	$$('div.summary')[0].setStyle({top: '1.8em', width: '14em'});
}
