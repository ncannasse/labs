package db;
import sys.db.Types;

class Entry extends sys.db.Object {

	public static var manager = new EntryManager(Entry);

	public var id : SId;
	public var batchId : SInt;
	public var date : SDate;
	public var title : STinyText;
	public var comment : STinyText;
	public var custom : STinyText;
	public var amount : SFloat;
	@:relation(pid)
	public var parent : SNull<Entry>;
	@:relation(gid)
	public var group : SNull<Group>;
	public var groupManual : SBool;

	public function accountValue() {
		return manager.accountValue(this);
	}

	public function hasSubEntry() {
		return manager.count({ pid : id }) > 0;
	}

}

class EntryManager extends sys.db.Manager<Entry> {
	
	function execute(rq) {
		return getCnx().request(rq);
	}

	public function newBatch() {
		return execute("SELECT MAX(batchId) FROM Entry").getIntResult(0) + 1;
	}

	public function currentSubAmount( e : Entry ) {
		return round(execute("SELECT SUM(amount) FROM Entry WHERE pid = "+e.id).getFloatResult(0));
	}

	function round(x:Float) {
		return Math.round(x*100) / 100;
	}

	public function accountValue( e : Entry ) {
		var a = Amount.manager.search($date <= e.date, { orderBy : -date },false).first();
		if( a == null )
			return Math.NaN;
		var edate = quote(e.date.toString());
		return a.amount + round(execute("SELECT SUM(amount) FROM Entry WHERE pid IS NULL AND date >= "+quote(a.date.toString())+" AND (date < "+edate+" OR (date = "+edate+" AND id <= "+e.id+"))").getFloatResult(0));
	}

	public function browse( pid : Int, group : db.Group, date : String, pos : Int, count : Int ) {
		var conds = [];
		if( group != null )
			conds.push((group.id == null) ? "gid IS NULL" : "gid = "+group.id);
		else if( pid == null )
			conds.push("pid IS NULL");
		else
			conds.push("pid = "+pid);
		if( date != null )
			conds.push("date LIKE "+quote(date+"%"));
		return unsafeObjects("SELECT * FROM Entry WHERE "+conds.join(" AND ")+" ORDER BY date DESC, id DESC LIMIT "+pos+","+count,false);
	}

	public function searchWord( s : String, pos : Int, count : Int ) {
		var words = s.split("+");
		var conds = new Array();
		for( w in words )
			conds.push("("+[
				"date LIKE "+quote(w+"%"),
				"title LIKE "+quote("%"+w+"%"),
				"custom LIKE "+quote("%"+w+"%"),
				"comment LIKE "+quote("%"+w+"%"),
				"amount = "+quote(w)
			].join(" OR ")+")");
		return unsafeObjects("SELECT * FROM Entry WHERE "+conds.join(" AND ")+" ORDER BY date DESC, id DESC LIMIT "+pos+","+count,false);
	}

	function makeCond( c : { year : Int, maxMonth : Int } ) {
		if( c == null ) return "TRUE";
		var cond = "TRUE";
		cond += " AND YEAR(date) = "+c.year;
		if( c.maxMonth != null )
			cond += " AND MONTH(date) <= "+c.maxMonth;
		return cond;
	}

	public function totalAmount( c, gid : Null<Int> ) {
		return round(execute("SELECT SUM(amount) FROM Entry WHERE gid = "+gid+" AND "+makeCond(c)).getFloatResult(0));
	}

	public function stats( ?c ) {
		var me = this;
		var months = execute("SELECT DISTINCT(LEFT(date,7)) as month FROM Entry WHERE "+makeCond(c)+" ORDER by month DESC").results();
		return months.map(function(r) {
			var m = r.month;
			var results = me.execute("SELECT gid, hasSubEntries, SUM(amount) as amount FROM Entry LEFT JOIN `Group` ON gid = Group.id WHERE LEFT(date,7) = "+me.quote(m)+" GROUP BY gid").results();
			var h = new Map<Int,Float>();
			for( r in results ) {
				var amount : Float = r.amount;
				if( r.hasSubEntries )
					amount -= me.execute("SELECT SUM(amount) FROM Entry WHERE pid IN (SELECT id FROM Entry WHERE LEFT(date,7) = "+me.quote(m)+")").getFloatResult(0);
				h.set(r.gid,round(amount));
			}
			return {
				month : m,
				datas : h,
			};
		});
	}

	public function allYears() : List<Int> {
		return execute("SELECT DISTINCT(LEFT(date,4)) as year FROM Entry ORDER by year DESC").results().map(function(r) return r.year);
	}
	
	public function statsPerYear() {
		return allYears().map(function(y) {
			var results = execute("SELECT gid, hasSubEntries, SUM(amount) as amount FROM Entry LEFT JOIN `Group` ON gid = Group.id WHERE LEFT(date,4) = "+y+" GROUP BY gid").results();
			var h = new Map<Int,Float>();
			for( r in results ) {
				var amount : Float = r.amount;
				if( r.hasSubEntries )
					amount -= execute("SELECT SUM(amount) FROM Entry WHERE pid IN (SELECT id FROM Entry WHERE LEFT(date,4) = "+y+")").getFloatResult(0);
				h.set(r.gid,round(amount));
			}
			return {
				month : ""+y,
				datas : h,
			};
		});
	}
	

	public function selectPossibleParents() {
		return unsafeObjects("SELECT Entry.* FROM Entry, `Group` WHERE gid = Group.id AND Group.hasSubEntries AND (SELECT COUNT(*) FROM Entry AS E2 WHERE E2.pid = Entry.id) = 0 ORDER BY date DESC",false);
	}

}