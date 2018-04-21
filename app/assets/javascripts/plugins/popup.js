  var popupshowDelay = 0.3; // delay in seconds before showing pullout
  var popuphideDelay = 0.2; // delay in seconds before hiding pullout
	var popupMode = 'hover'; // 'hover' or 'static'
	var popupPosition = 'below-right'; // 'above-left', 'above-right', 'below-left' or 'below-right'
	var popupMaxWidth = 400; // max width of a popup box

	var popupTimer = new Array();
	var popupShadowDisplacement = navigator.userAgent.indexOf("MSIE")==-1 ? 0 : 2;
	var popupAnchorToBox = 14;
	var popupBoxToArrow = 5;
	var popupScreenMargin = 5;
	
  function randomId() {
	  var id = 'pw_';
		for (var i=0; i<16; i++) {
		  id = id + Math.floor(Math.random()*10);
		}
		return id;
	}	  

  function findPos(obj) {
  	var curleft = curtop = 0;
  	if (obj.offsetParent) {
  		curleft = obj.offsetLeft
  		curtop = obj.offsetTop
  		while (obj = obj.offsetParent) {
  			curleft += obj.offsetLeft
  			curtop += obj.offsetTop
  		}
  	}
  	return [curleft,curtop];
  }

  function windowSize() {
    var myWidth = 0, myHeight = 0;
    if( typeof( window.innerWidth ) == 'number' ) {
      //Non-IE
      myWidth = window.innerWidth;
      myHeight = window.innerHeight;
    } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
      //IE 6+ in 'standards compliant mode'
      myWidth = document.documentElement.clientWidth;
      myHeight = document.documentElement.clientHeight;
    } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
      //IE 4 compatible
      myWidth = document.body.clientWidth;
      myHeight = document.body.clientHeight;
    }
    return [myWidth,myHeight];
  }	
	
  function showPopup() {
		// ensure the element has an id
	  if (!this.id) this.id = randomId();
		// get the id of the anchor element
		var anchorId = this.id;
		// create an id for the popup elemenet
		var popupId = anchorId + '_popup';
		// create an id for the arrow elemenet
		var arrowId = anchorId + '_arrow';

		// store the existing title attribite, and clear it so that the browser does not show tooltips 
		var popupText = this.title;
		this.title = '';
		popupText = popupText.replace(/  /g,'<br />'); // convert double space to line break
		popupText = popupText.replace(/\*(.*?)\*/g,'<strong>$1</strong>'); // convert *'s to strong
		popupText = popupText.replace(/\_(.*?)\_/g,'<em>$1</em>'); // convert _'s to em
		
		// get the body element
		var parentNode = document.documentElement.firstChild;
		parentNode = parentNode.nextSibling;
		while (parentNode.nodeName != 'BODY')
		  parentNode = parentNode.nextSibling;

		// check if the div is already created
		var popupDiv = document.getElementById(popupId);
		var arrowDiv = document.getElementById(arrowId);
		if (!popupDiv) {
  	  if (navigator.userAgent.indexOf('Opera') != -1 && this.tagName == 'A' && this.getAttribute('href')) { 
			  // Opera only hack to remove browser popup with the hyperlink
    		hyperlink = this.href;
    		this.removeAttribute('href');
  			this.style.color = 'blue';
  			this.style.textDecoration = 'underline';
  			this.style.cursor = 'pointer';
  			this.onclick = function() { location.href = hyperlink; };
			}
							
  		// create the div, style it, and attach it to the parent node
			popupDiv = document.createElement('div');
  		popupDiv.id = popupId;
  		popupDiv.className = 'popup';
  		popupDiv.innerHTML = popupText;
  		parentNode.appendChild(popupDiv);
  		if (popupDiv.offsetWidth > popupMaxWidth) popupDiv.style.width = popupMaxWidth + 'px';

  		popupTimer[popupId] = 0;
  		popupTimer[arrowId] = 0;
		}
		if (!arrowDiv) {	
  		// create the div, style it, and attach it to the parent node
			arrowDiv = document.createElement('img');
  		arrowDiv.setAttribute('id',arrowId);
			arrowDiv.className = 'arrow';
  		parentNode.appendChild(arrowDiv);
		}

		// reposition the divs
		repositionDiv(anchorId);

		// show the div's
  	showDiv(popupId);
  	showDiv(arrowId);
	}

  function repositionDiv(anchorId) {
		// create an id for the popup elemenet
		var popupId = anchorId + '_popup';
		// create an id for the arrow elemenet
		var arrowId = anchorId + '_arrow';

		// get the div handles
	  var anchorDiv = document.getElementById(anchorId);
		var popupDiv = document.getElementById(popupId);
		var arrowDiv = document.getElementById(arrowId);
	
	  // find the position of the anchor
		var pos = findPos(anchorDiv);
		var left = pos[0];
		var top = pos[1];
		var pos = windowSize();
		var right = pos[0];

		// work out where we are going to put the popup
		var popupPos = (anchorDiv.rel) ? anchorDiv.rel : popupPosition;
				
    // reposition the divs
		if (popupPos == 'above-left') {
		  if (top - popupAnchorToBox - popupDiv.offsetHeight < 0) {
			  popupPos = 'below-left';
			}
  		popupDiv.style.left = Math.min(right - popupScreenMargin - popupDiv.offsetWidth, Math.max(popupScreenMargin, left + anchorDiv.offsetWidth - popupAnchorToBox - popupDiv.offsetWidth)) + 'px';
			popupDiv.style.top = Math.max(popupScreenMargin, top - popupAnchorToBox - popupDiv.offsetHeight) + 'px';
			arrowDiv.src = '/assets/titles/arrow3.gif';
  		arrowDiv.style.left = left + anchorDiv.offsetWidth - popupAnchorToBox - popupBoxToArrow - popupShadowDisplacement - arrowDiv.offsetWidth + 'px';
  		arrowDiv.style.top = top - popupAnchorToBox - popupShadowDisplacement - 1 + 'px';
		} 
		if (popupPos == 'above-right') {
		  if (top - popupAnchorToBox - popupDiv.offsetHeight < 0) {
			  popupPos = 'below-right';
			}
  		popupDiv.style.left = Math.min(right - popupScreenMargin - popupDiv.offsetWidth, Math.max(popupScreenMargin, left + popupAnchorToBox)) + 'px';
			popupDiv.style.top = Math.max(popupScreenMargin, top - popupAnchorToBox - popupDiv.offsetHeight) + 'px';
			arrowDiv.src = '/assets/titles/arrow4.gif';
  		arrowDiv.style.left = left + popupAnchorToBox + popupBoxToArrow + 'px';
  		arrowDiv.style.top = top - popupAnchorToBox - popupShadowDisplacement - 1 + 'px';
		}
		if (popupPos == 'below-right') {
  		popupDiv.style.left = Math.min(right - popupScreenMargin - popupDiv.offsetWidth, Math.max(popupScreenMargin, left + popupAnchorToBox)) + 'px';
  		popupDiv.style.top = Math.max(popupScreenMargin, top + anchorDiv.offsetHeight + popupAnchorToBox) + 'px';
			arrowDiv.src = '/assets/titles/arrow2.gif';
  		arrowDiv.style.left = Math.max(popupScreenMargin, left + popupAnchorToBox + popupBoxToArrow) + 'px';
  		arrowDiv.style.top = Math.max(popupScreenMargin, top + anchorDiv.offsetHeight + popupAnchorToBox - arrowDiv.offsetHeight + 1) + 'px';
		} 
		if (popupPos == 'below-left') {
  		popupDiv.style.left = Math.min(right - popupScreenMargin - popupDiv.offsetWidth, Math.max(popupScreenMargin, left + anchorDiv.offsetWidth - popupAnchorToBox - popupDiv.offsetWidth)) + 'px';
  		popupDiv.style.top = Math.max(popupScreenMargin, top + anchorDiv.offsetHeight + popupAnchorToBox) + 'px';
			arrowDiv.src = '/assets/titles/arrow1.gif';
  		arrowDiv.style.left = Math.max(popupScreenMargin, left + anchorDiv.offsetWidth - popupAnchorToBox - popupBoxToArrow - popupShadowDisplacement - arrowDiv.offsetWidth) + 'px';
  		arrowDiv.style.top = Math.max(popupScreenMargin, top + anchorDiv.offsetHeight + popupAnchorToBox - arrowDiv.offsetHeight + 1) + 'px';
		} 
	}
	
	function showDiv(divName,action) {
		clearTimeout(popupTimer[divName]);
		popupDiv = divName + '_popup';
		arrowDiv = divName + '_arrow';
		
		if (action == 'hide') {
  	  // hide a div based on it's name
  		popupTimer[divName] = setTimeout("document.getElementById('"+divName+"').style.visibility = 'hidden';",1000*popuphideDelay);
		}
		else {
  	  // hide a div based on it's name
  		popupTimer[divName] = setTimeout("document.getElementById('"+divName+"').style.visibility = 'visible';",1000*popupshowDelay);
		}
	}


	function resize() {
	//	for (var id in popupTimer) {
	//	  if (document.getElementById(id)) {
  	//		if (document.getElementById(id).style.visibility == 'visible' && id.indexOf('_arrow') != -1) {
  	//		  var parentId = id.substr(0,id.length-6);
  	//			repositionDiv(parentId);
    	//	}
	//		}
	//	}
	}
	
  function hidePopup() {
		// ensure the element has an id
	  if (!this.id) this.id = randomId();
		// get the id of the anchor element
		var anchorId = this.id;
		// create an id for the popup elemenet
		var popupId = anchorId + '_popup';
		// create an id for the arrow elemenet
		var arrowId = anchorId + '_arrow';

		// check if the div is already created
		var popupDiv = document.getElementById(popupId);
		var arrowDiv = document.getElementById(arrowId);

  	showDiv(popupId,'hide');
  	showDiv(arrowId,'hide');
	}
	
  function getElementsWithTitles() { 
		// check browser is capable
    if (!document.getElementsByTagName) 
		  return; 

	  // get all elements on page
    var elements_all = document.getElementsByTagName("*"); 
		// scan through elements looking for title attribute
    for (var i=0; i<elements_all.length; i++) { 
      var element = elements_all[i]; 
      var title = element.title; 
			// attach the new functions to mouse event of the element
			if (title && popupMode == 'hover') {
			  element.onmouseover = showPopup;
			  element.onmouseout = hidePopup;
			}
			// attach the new functions to the load event of the element
			else if (title && popupMode == 'static') {
			  element.onload = showPopup;
			  element.onload();
			}
    } 
  } 

