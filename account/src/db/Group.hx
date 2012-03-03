package db;
import sys.db.Types;

class Group extends sys.db.Object {

	public var id : SId;
	public var name : STinyText;
	public var hasSubEntries : SBool;

	override function toString() {
		return id+" - "+name;
	}

}