package db;
import sys.db.Types;

class Note extends sys.db.Object {

	public var id : SId;
	public var created : SDateTime;
	public var modified : SDateTime;
	public var title : STinyText;
	public var content : SText;
	public var hidden : SBool;
	
}