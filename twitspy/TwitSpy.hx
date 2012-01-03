typedef Infos = {
	var lang : String;
	var name : String;
	var url : String;
	var description : String;
	var friends_count : Int;
	var followers_count : Int;
	var screen_name : String;
	var statuses_count : Int;
}

class TwitSpy {

	static var buf : haxe.io.BytesOutput;

	static function print(str) {
		neko.Lib.println(str);
	}

	static function w(str) {
		buf.writeString(str+"\n");
	}

	static function eval(json) : Dynamic {
		var h = new hscript.Parser();
		h.allowJSON = true;
		var e = h.parse(new haxe.io.StringInput(json));
		return new hscript.Interp().execute(e);
	}

	static function main() {
		var name = neko.Sys.args()[0];
		if( name == null )
			name = "ncannasse";
		print("Fetching followers for "+name);
		var h = haxe.Http.requestUrl("http://api.twitter.com/1/followers/ids.json?screen_name="+name);
		var ids : Array<Int> = eval(h).ids;
		print(ids.length+" followers found");
		var all = new Array<Infos>();
		while( ids.length > 0 ) {
			var list = ids.splice(0,100);
			print("Fetching "+list.length+" followers infos");
			var h = haxe.Http.requestUrl("http://api.twitter.com/1/users/lookup.json?user_id="+list.join(","));
			var infos : Array<Infos> = eval(h);
			all = all.concat(infos);
		}
		all.sort(function(a,b) return b.followers_count - a.followers_count);

		print("Building data");

		buf = new haxe.io.BytesOutput();

		w("<p>"+Date.now().toString()+" "+all.length+" followers");
		w("<div class='raw' style='display:none'>"+haxe.Serializer.run(all)+"</div>");
		w("<table>");
		w("<tr>");
		for( h in ["Name","Followers","Following","Tweets","Lang","Website"] )
			w("<th>"+h+"</th>");
		w("</tr>");
		for( i in all ) {
			w("<tr>");
			var link = '<a href="http://twitter.com/'+i.screen_name+'">'+i.name+'</a>';
			var url = i.url == null ? "" : '<a href="'+i.url+'">'+i.url+'</a>';
			for( v in [link,i.followers_count,i.friends_count,i.statuses_count,i.lang,url] )
				buf.writeString("<td>"+v+"</td>");
			w("</tr>");
			if( i.description != null )
				w("<tr><td></td><td class='desc' colspan='6'>"+i.description+'</td></tr>');
		}
		w("</table>");

		var data = neko.Lib.stringReference(buf.getBytes());


		var filename = "twitspy.html";
		print("Saving to "+filename);

		var str = try neko.io.File.getContent(filename) catch( e : Dynamic ) null;
		if( str == null ) {
			str = '<meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>\n';
			str += "<style>td.desc { font-size : 12px; color : #777 }</style>\n";
			str += data;
		} else {
			var parts = str.split("<p>");
			var head = parts.shift();
			str = head+data+"<p>"+parts.join("<p>");
		}

		var file = neko.io.File.write(filename);
		file.writeString(str);
		file.close();

		print("Done");
	}

}