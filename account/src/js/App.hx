package js;
import js.Tip;

class App {

	static function toggle( id ) {
		var t = js.Lib.document.getElementById(id);
		if( t == null ) throw "Unknown element "+id;
		t.style.display = (t.style.display == 'none')?'':'none';
		return false;
	}

}