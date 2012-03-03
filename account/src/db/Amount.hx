package db;
import sys.db.Types;

@:id(date)
class Amount extends sys.db.Object {

	public var date : SDate;
	public var amount : SFloat;

}