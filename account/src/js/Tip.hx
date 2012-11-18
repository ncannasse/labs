package js;

import js.Dom;

typedef Pos = {
	x: Int,
	y: Int
}

typedef Size = {> Pos,
	width: Int,
	height: Int
}

typedef WSize = {> Size,
	scrollTop: Int,
	scrollLeft: Int
}


@:expose
@:keep
class Tip {
	public static var xOffset = 3;
	public static var yOffset = 22;
	public static var defaultClass = "normalTip";
	public static var tooltipId = "tooltip";
	public static var tooltipContentId = "tooltipContent";
	public static var minOffsetY = 23;

	public static var lastRef : js.HtmlDom;
	static var placeRef : Bool;
	static var initialized : Bool;
	public static var tooltip : js.HtmlDom;
	public static var tooltipContent : js.HtmlDom;

	public static var mousePos : Pos;
	public static var onHide : Void -> Void;

	static var excludeList : List<js.HtmlDom>;

	public static function show( refObj : js.HtmlDom, contentHTML : String, ?cName : String, ?pRef : Bool ){
		init();
		if( tooltip == null ){
			tooltip = js.Lib.document.getElementById( tooltipId );
			if( tooltip == null ){
				tooltip = js.Lib.document.createElement("div");
				tooltip.id = tooltipId;
				js.Lib.document.body.insertBefore(tooltip,js.Lib.document.body.firstChild);
			}
			tooltip.style.top = "-1000px";
			tooltip.style.position = "absolute";
			tooltip.style.zIndex = 10;
		}
		if( tooltipContent == null ){
			tooltipContent = js.Lib.document.getElementById( tooltipContentId );
			if( tooltipContent == null ){
				tooltipContent = js.Lib.document.createElement("div");
				tooltipContent.id = tooltipContentId;
				tooltip.appendChild(tooltipContent);
			}
		}

		if( pRef == null ) pRef = false;
		placeRef = pRef;

		if( cName == null )
			tooltip.className = defaultClass;
		else
			tooltip.className = cName;

		if( lastRef != null && onHide != null ){
			onHide();
			onHide = null;
		}

		lastRef = refObj;

		tooltipContent.innerHTML = contentHTML;

		if( placeRef )
			placeTooltipRef();
		else
			placeTooltip();
	}

	public static function exclude( id : String ) {
		var e = js.Lib.document.getElementById(id);
		if( e == null )
			throw id+" not found";
		if( excludeList == null )
			excludeList = new List();
		excludeList.add(e);
	}

	public static function placeTooltip() {
		if( mousePos == null ) return;

		var tts = elementSize( tooltip );
		var w = windowSize();
		var top = 0;
		var left = 0;

		left = mousePos.x + xOffset;
		top = mousePos.y + yOffset;

		if( top + tts.height > w.height -2 + w.scrollTop  ){
			if( mousePos.y - tts.height > 5 + w.scrollTop )
			top = mousePos.y - tts.height - 5;
			else
				top = w.height -2 + w.scrollTop - tts.height;
		}
		if( left + tts.width > w.width - 22 + w.scrollLeft ){
			if( mousePos.x - tts.width > 5 + w.scrollLeft )
			left = mousePos.x - tts.width - 5;
			else
				left = w.width - 22 + w.scrollLeft - tts.width;
		}

		if( top < 0 ) top = 0;
		if( left < 0 ) left = 0;

		if( excludeList != null )
			for( e in excludeList ) {
				var s = elementSize(e);
				if( left > s.x + s.width || left + tts.width < s.x || top > s.y + s.height || top + tts.height < s.y )
					continue;
				var dx1 = left - (s.x + s.width);
				var dx2 = left + tts.width - s.x;
				var dx = (Math.abs(dx1) > Math.abs(dx2)) ? dx2 : dx1;
				var dy1 = top - (s.y + s.height);
				var dy2 = top + tts.height - s.y;
				var dy = (Math.abs(dy1) > Math.abs(dy2)) ? dy2 : dy1;

				var cx = (left + tts.width/2) - mousePos.x;
				var cy = (top + tts.height/2) - mousePos.y;

				if( (cx - dx) * (cx - dx) + cy * cy > cx * cx + (cy - dy) * (cy - dy) )
					top -= dy;
				else
					left -= dx;
			}

		tooltip.style.left = left+"px";
		tooltip.style.top = top+"px";
	}

	public static function placeTooltipRef(){
		var o = elementSize( lastRef );
		var tts = elementSize( tooltip );

		if( o.width <= 0 )
			tooltip.style.left = ( o.x ) + "px";
		else
			tooltip.style.left = ( o.x - tts.width * 0.5 + o.width * 0.5 ) + "px";

		tooltip.style.top = ( o.y + Math.max(minOffsetY,o.height) ) + "px";
	}


	public static function showTip( refObj: js.HtmlDom, title : String, contentBase : String ){
		contentBase = "<p>"+contentBase+"</p>";

		show( refObj, "<div class=\"title\">"+title+"</div>"+contentBase );
	}

	public static function hide(){
		if( lastRef == null ) return;
		lastRef = null;

		if( onHide != null ){
			onHide();
			onHide = null;
		}

		tooltip.style.top = "-1000px";
		tooltip.style.width = "";
	}

	public static function clean(){
		if( lastRef == null ) return;
		if( lastRef.parentNode == null ) return hide();
		if( lastRef.id != null && lastRef.id != "" ){
			if( js.Lib.document.getElementById(lastRef.id) != lastRef ) return hide();
		}
		return;
	}

	public static function elementSize( o : js.HtmlDom ) : Size {
		var ret = {
			x: 0,
			y: 0,
			width: o.clientWidth,
			height: o.clientHeight
		};

		var p = o;
		while( p != null ){
			if( p.offsetParent != null ){
				ret.x += p.offsetLeft - p.scrollLeft;
				ret.y += p.offsetTop - p.scrollTop;
			}else{
				ret.x += p.offsetLeft;
				ret.y += p.offsetTop;
			}
			p = p.offsetParent;
		}

		return ret;
	}

	public static function windowSize() : WSize {
		var ret = {
			x: 0,
			y: 0,
			width: untyped js.Lib.window.innerWidth,
			height: untyped js.Lib.window.innerHeight,
			scrollLeft: js.Lib.document.body.scrollLeft + untyped js.Lib.document.documentElement.scrollLeft,
			scrollTop: js.Lib.document.body.scrollTop + untyped js.Lib.document.documentElement.scrollTop
		};

		var isIE = untyped document.all != null && window.opera == null;
		
		var body = if( isIE ) untyped js.Lib.document.documentElement else js.Lib.document.body;

		if( ret.width == null ) ret.width = body.clientWidth;
		if( ret.height == null ) ret.height = body.clientHeight;

		return ret;
	}

	static function onMouseMove( evt : js.Event ){
		try {
		var posx = 0;
		var posy = 0;
		if (evt == null) evt = untyped js.Lib.window.event;
		var e : Dynamic = cast evt;
		if(e.pageX || e.pageY){
			posx = e.pageX;
			posy = e.pageY;
		}else if(e.clientX || e.clientY){
			posx = e.clientX + js.Lib.document.body.scrollLeft + untyped js.Lib.document.documentElement.scrollLeft;
			posy = e.clientY + js.Lib.document.body.scrollTop + untyped js.Lib.document.documentElement.scrollTop;
		}
		mousePos = {x: posx, y: posy};

		if( lastRef != null && !placeRef ) placeTooltip();
		}catch( e : Dynamic ){
		}
	}

	public static function trackMenu( elt : HtmlDom, onOut : Void -> Void ) {
		init();
		var ftrack = null;
		var body = js.Lib.document.body;
		ftrack = function( evt : js.Event ) {
			if( mousePos == null ) return;
			var size = elementSize(elt);
			if( mousePos.x < size.x || mousePos.y < size.y || mousePos.x > size.x + size.width || mousePos.y > size.y + size.height ) {
				untyped if( body.attachEvent )
					body.detachEvent('onmousemove', ftrack);
				else
					body.removeEventListener('mousemove', ftrack, false);
				onOut();
			}
		};
		untyped if( body.attachEvent )
			body.attachEvent('onmousemove', ftrack);
		else
			body.addEventListener('mousemove', ftrack, false);
	}

	public static function init(){
		if( initialized ) return;
		untyped if( document.body != null ){
			initialized = true;
			document.body.onmousemove = onMouseMove;
		}
	}

	static function __init__() : Void {
		init();
	}
}
