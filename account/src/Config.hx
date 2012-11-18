class Config {

	static var xml = Xml.parse(sys.io.File.getContent(neko.Web.getCwd()+"../config.xml")).firstElement();

	public static function get( att : String, ?def ) {
		var v = xml.get(att);
		if( v == null )
			v = def;
		if( v == null )
			throw "Missing config attribute "+att;
		return v;
	}

	public static var DEBUG = get("debug","0") == "1";
	public static var CACHE = get("cache","0") == "1";
	public static var TPL = neko.Web.getCwd()+"../tpl/fr/";

}