package db;
import sys.db.Types;

class Rule extends sys.db.Object {

	public var id : SId;
	public var ereg : STinyText;
	@:relation(gid)
	public var group : Group;

}