class App {

	public static var database : sys.db.Connection;
	public static var request : mtwin.web.Request;
	public static var context : Dynamic;
	static var template : templo.Loader;

	static function sendNoCacheHeaders() {
		try {
			neko.Web.setHeader("Cache-Control", "no-store, no-cache, must-revalidate");
			neko.Web.setHeader("Pragma", "no-cache");
			neko.Web.setHeader("Expires", "-1");
			neko.Web.setHeader("P3P", "CP=\"ALL DSP COR NID CURa OUR STP PUR\"");
			neko.Web.setHeader("Content-Type", "text/html; Charset=UTF-8");
			neko.Web.setHeader("Expires", "Mon, 26 Jul 1997 05:00:00 GMT");
		} catch( e : Dynamic ) {
		}
	}

	public static function prepareTemplate( t : String ) {
		templo.Loader.OPTIMIZED = Config.DEBUG == false;
		templo.Loader.BASE_DIR = Config.TPL;
		templo.Loader.TMP_DIR = Config.TPL + "../tmp/";
		sendNoCacheHeaders();
		template = new templo.Loader(t);
	}

	static function executeTemplate() {
		var result = template.execute(context);
		sendNoCacheHeaders();
		neko.Lib.print(result);
	}

	static function redirect( url:String, ?text : String, ?params : Dynamic, ?error : Bool ) {
		template = null;
		sendNoCacheHeaders();
		if( text != null ) {
			var t = new haxe.Template(text);
			text = t.execute(params);
			if( url.indexOf("?") < 0 )
				url += "?";
			else
				url += ";";
			url += "__text="+StringTools.urlEncode(text)+(error?";__error=1":"");
		}
		neko.Web.redirect(url);
	}

	static function mainLoop() {
		request = new mtwin.web.Request();
		context = {};
		var h = new handler.Main();
		var level = if( request.getPathInfoPart(0) == "index.n" ) 1 else 0;
		try {
			h.execute(request,level);
		} catch( e : handler.Action ) {
			switch( e ) {
			case Goto(url):
				redirect(url);
			case Error(url,err,params):
				database.rollback();
				sys.db.Manager.cleanup();
				redirect(url,err,params,true);
			case Done(url,conf,params):
				redirect(url,conf,params,false);
			case JsError(msg,params):
				neko.Lib.print("alert('"+escapeJS(new haxe.Template(msg).execute(params))+"')");
			}
		}
		if( template != null )
			initContext();
		if( template != null )
			executeTemplate();
	}

	public static function initDatabase( params : String ) {
		var m = ~/^mysql:\/\/(.*):(.*)@(.*):(.*)\/(.*)$/;
		if( !m.match(params) )
			throw "Invalid format "+params;
		return sys.db.Mysql.connect({
			user : m.matched(1),
			pass : m.matched(2),
			host : m.matched(3),
			port : Std.parseInt(m.matched(4)),
			database : m.matched(5),
			socket : null
		});
	}

	static function escapeJS(text) {
		return text.split("\\").join("\\\\").split("'").join("\\'").split("\r").join("\\r").split("\n").join("\\n");
	}

	static function initContext() {
		context.request = request;
		context.api = {
			escapeJS : escapeJS,
			percent : function(v1,v2) return Std.int((v1 * 1000.0) / v2) / 10,
			date : function(d:Date) return d.toString().substr(0,10),
			ifnull : function(e,o) return (e == null) ? o : e,
			round : function(v) return Math.round(v),
		};
		if( request != null && request.exists("__text") )
			context.notification = { text : request.get("__text"), error : request.exists("__error") };
	}

	static function errorHandler( e : Dynamic ) {
		try {
			if( database != null ) database.rollback();
			prepareTemplate("error.mtt");
			context = {};
			initContext();
			context.error = Std.string(e);
			context.stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			executeTemplate();
		} catch( e : Dynamic ) {
			neko.Lib.rethrow(e);
		}
	}

	static function cleanup() {
		if( database != null ) {
			database.close();
			database = null;
		}
		template = null;
		request = null;
		context = null;
	}

	static function main() {
		if( !Sys.setTimeLocale(Text.get.locale1) )
			Sys.setTimeLocale(Text.get.locale2);
		try {
			database = initDatabase(Config.get("db"));
		} catch( e : Dynamic ) {
			errorHandler(e);
			cleanup();
			return;
		}
		sys.db.Transaction.main(database, mainLoop, errorHandler);
		database = null; // already closed
		cleanup();
		if( Config.CACHE ) neko.Web.cacheModule(main);
	}
}