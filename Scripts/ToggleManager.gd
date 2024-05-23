extends Node

var item_list:Array=[];
var enabled_callback:Callable; # should be callable on items
var disabled_callback:Callable;
var _idx=-1;
var _toggling:bool=false;

func default():
	# sets default item
	if (len(item_list)==0):
		return;
	_idx=0;
	toggle_index(_idx);
	
func is_toggling():
	return _toggling;
	
func toggle_index(idx:int):
	# toggles to the current index; performing all necessary updates
	if(idx==_idx || _toggling):
		return;
	_idx=idx;
	_toggling=true;
	for i in range(len(item_list)):
		var item=item_list[i];
		disabled_callback.call(item);
	enabled_callback.call(item_list[idx]);
	_toggling=false;
