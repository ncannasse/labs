package handler;
import format.pdf.Data;

class Main extends mtwin.web.Handler<Void> {

	override function prepareTemplate( t:String ) : Void {
		App.prepareTemplate(t);
	}

	override function initialize() {
		free("default", "main.mtt", doMain );
		free("db", sys.db.Admin.handler );
		free("upload", "upload.mtt", doUpload );
		free("auto", doAuto );
		free("update", doUpdate );
		free("stats", "stats.mtt", doStats );
		free("notes", "notes.mtt", doNotes );
	}

	function doMain() {
		var page = request.getInt("page",0);
		var parent = request.getInt("parent");
		var group = db.Group.manager.get(request.getInt("group"),false);
		var date = request.get("date");
		var search = request.get("search");
		if( parent == 0 ) parent = null;
		var groups = Lambda.array(db.Group.manager.all(false));
		var url = "/?";
		if( request.get("group") == "null" )
			group = new db.Group();
		if( parent != null )
			url += "parent="+parent+";";
		if( group != null )
			url += "group="+group.id+";";
		if( date != null )
			url += "date="+date+";";
		if( search != null )
			url += "search="+StringTools.urlEncode(search)+";";
		var count = (parent == null) ? 20 : 1000;
		groups.sort(function(g1,g2) return Reflect.compare(g1.name,g2.name));
		App.context.page = page;
		App.context.parent = parent;
		App.context.groups = groups;
		App.context.entries = if( search != null ) db.Entry.manager.searchWord(search,page*count,count) else db.Entry.manager.browse(parent,group,date,page * count,count);
		App.context.waiting = db.Entry.manager.count({ gid : null });
		App.context.url = url;
	}

	function doStats() {
		var groups = db.Group.manager.all(false);
		var g = new db.Group();
		g.name = "???";
		groups.add(g);
		var cond = request.exists("year") ? { year : request.getInt("year"), maxMonth : null } : null;
		if( cond != null && cond.year == Date.now().getFullYear() )
			cond.maxMonth = Date.now().getMonth();
		App.context.groups = groups.filter(function(g) return db.Entry.manager.totalAmount(cond, g.id) != 0);
		var perYear = cond == null && request.exists("perYear");
		if( perYear )
			App.context.perYear = true;
		if( cond != null )
			App.context.currentYear = cond.year;
		App.context.stats = if( perYear ) db.Entry.manager.statsPerYear() else db.Entry.manager.stats(cond);
		App.context.totalAmount = db.Entry.manager.totalAmount.bind(cond);
	}

	function doUpdate() {
		var e = db.Entry.manager.get(request.getInt("id"));
		if( request.exists("group") ) {
			e.group = db.Group.manager.get(request.getInt("group"));
			e.groupManual = true;
		}
		if( request.exists("custom") )
			e.custom = request.get("custom");
		e.update();
		throw Action.Goto(request.getReferer());
	}

	function guessGroup(title) {
		for( r in db.Rule.manager.all(false) ) {
			var reg = new EReg("^" +  r.ereg + "$","i");
			if( reg.match(title) )
				return r.group;
		}
		return null;
	}

	function doAuto() {
		var count = 0;
		var el = db.Entry.manager.search({ gid : null },true);
		for( e in el ) {
			e.group = guessGroup(e.title);
			if( e.group != null )
				count++;
			e.update();
		}
		throw Action.Done(request.getReferer(),count+"/"+el.length+" entries updated");
	}

	function doUpload() {
		if( !request.exists("submit") ) {
			App.context.parentEntries = db.Entry.manager.selectPossibleParents();
			return;
		}
		var params = neko.Web.getMultipart(1000000);
		var data = params.get("file");
		var datas = if( data.substr(0,4) == "%PDF" ) readCofPDF(data) else readCAExcel(data);
		// insert into database
		var count = 0;
		var batch = db.Entry.manager.newBatch();
		var parent = db.Entry.manager.get(Std.parseInt(params.get("parent")));
		var total = if( parent == null ) 0. else db.Entry.manager.currentSubAmount(parent);
		var log = new Array();
		for( d in datas ) {
			total += d.amount;
			var prev = db.Entry.manager.select( { title : d.title, date : d.date, amount : d.amount, comment : d.comment }, false );
			if( prev != null && prev.batchId != batch )
				continue;
			var e = new db.Entry();
			e.batchId = batch;
			e.date = d.date;
			e.title = d.title;
			e.comment = d.comment;
			e.amount = d.amount;
			e.group = guessGroup(d.title);
			e.parent = parent;
			e.insert();
			log.push(d.title+" "+d.amount);
			count++;
		}
		if( parent != null && Math.abs(parent.amount - total) > 0.0001 ) {
			var err = "Parent amount "+parent.amount+" differs from total "+total+"<br/>";
			err += log.join("<br/>");
			throw err;
		}
		var url = (parent == null) ? "/" : "/?parent="+parent.id;
		throw Action.Done(url,"Added "+count+"/"+datas.length+" entries with batch #"+batch);
	}

	function readCAExcel( data : String ) {
		data = data.split("\r\n").join("\n").split("\r").join("\n");
		var curyear = Date.now().getFullYear();
		var lastmonth = 0;
		var lines = data.split("\n\n\n");
		lines.reverse();
		var list = new List();

		for( d in lines ) {
			var d = d.split("\n").join("#");
			var r = ~/C;K"([0-9][0-9])-([A-Z][a-zé][a-zû])".*C;K"([^"]*)\x1B :([^"]*)".*X([34])#C;K([0-9.]+)/;
			if( !r.match(d) )
				continue;
			var day = Std.parseInt(r.matched(1));
			var month = r.matched(2);
			var title = StringTools.trim(r.matched(3));
			var comment = StringTools.trim(r.matched(4));
			var credit = r.matched(5) == "4";
			var amount = Std.parseFloat(r.matched(6)) * (credit ? 1 : -1);

			// process
			var month = switch( month ) {
				case "Jan": 1;
				case "Fév": 2;
				case "Mar": 3;
				case "Avr": 4;
				case "Mai": 5;
				case "Jun": 6;
				case "Jul": 7;
				case "Aoû": 8;
				case "Sep": 9;
				case "Oct": 10;
				case "Nov": 11;
				case "Déc": 12;
				default: throw "Invalid month "+month;
			}
			// if we are processing records from previous year
			if( lastmonth == 0 && month >= 11 && Date.now().getMonth() <= 2 )
				curyear--;
			// if we reach next year
			if( month == 1 && lastmonth == 12 )
				curyear++;
			var date = Date.fromString(curyear+"-"+((month < 10)?"0"+month:""+month)+"-"+((day < 10)?"0"+day:""+day));
			lastmonth = month;

			title = ~/ +/g.replace(title," ");
			if( comment == "." )
				comment = "";

			list.add({ date : date, title : title, comment : comment, amount : amount });
		}
		return list;
	}

	function readCofPDF( data : String ) {
		var list = new List();
		var i = new haxe.io.StringInput(data);
		var data = new format.pdf.Reader().read(i);
		data = new format.pdf.Crypt().decrypt(data);
		data = new format.pdf.Filter().unfilter(data);
		var streamData = null;
		for( x in data )
			switch( x ) {
			case DIndirect(_,_,v):
				switch( v ) {
				case DStream(data,_):
					var data = data.toString();
					if( !~/Fmpdf0/.match(data) )
						continue;
					streamData = data;
					break;
				default:
				}
			default:
			}
		if( streamData == null ) throw "Stream not found";
		var r = ~/\(([^\)]+)\) Tj/;
		var strings = new Array();
		while( r.match(streamData) ) {
			strings.push(r.matched(1));
			streamData = r.matchedRight();
		}
		var rdate = ~/^([0-9][0-9])\.([0-9][0-9])\.([0-9][0-9])$/;
		var ramount = ~/^(-?[0-9]+),([0-9][0-9])$/;
		while( strings.length > 0 ) {
			var date = strings.shift();
			if( !rdate.match(date) )
				continue;
			var title = strings.shift();
			var amount = strings.shift();
			if( !ramount.match(amount) ) {
				if( strings.length < 2 || !ramount.match(strings[1]) )
					continue;
				title += amount;
				title += strings.shift();
				amount = strings.shift();
			}
			title = haxe.Utf8.encode(title);
			title = ~/ +/g.replace(title," ");
			// skip direct pay
			if( !~/^Achat CB /.match(title) && !~/^Retrait /.match(title) && !~/Annulation Achat CB /.match(title) )
				continue;
			var date = Date.fromString( "20"+ rdate.matched(3) + "-" + rdate.matched(2) + "-" + rdate.matched(1) );
			var amount = -Std.parseFloat( ramount.matched(1)+"."+ramount.matched(2) );
			list.add({ date : date, title : title, comment : "", amount : amount });
		}
		return list;
	}

	function doNotes() {
		App.context.notes = db.Note.manager.search(!$hidden,{ orderBy : -created },false);
		if( request.exists("name") ) {
			var n = new db.Note();
			n.title = request.get("name");
			n.created = n.modified = Date.now();
			n.insert();
			throw Action.Goto("/notes?id=" + n.id);
		}
		var n = db.Note.manager.get(request.getInt("id"));
		if( n != null && request.exists("content") ) {
			var content = StringTools.trim(request.get("content"));
			if( content != n.content ) {
				n.content = content;
				n.modified = Date.now();
				n.update();
			}
			throw Action.Goto("/notes?id=" + n.id);
		}
		App.context.note = n;
	}

}