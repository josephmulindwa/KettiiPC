extends Node

var state_changed_callback=null;
var _states=[];
var _state_int=0;

func get_state():
	return _state_int;

func add_states(states):
	_states=states;

func add_state(state):
	_states.append(state);

func check_if_state_is(state):
	var i=_states.find(state);
	if (i==-1):
		return null;
	var k=(_state_int>>i)&0x1;
	return (k==1);
	
func append_state(state):
	# adds a state to the current state
	var r=get_state_representation(state);
	if (r==null):
		return false;
	var _prev_state=_state_int;
	_state_int=(_state_int | r);
	if (state_changed_callback!=null && (_prev_state!=_state_int)):
		state_changed_callback.call(_state_int);
	return true;

func set_state(state):
	var r=get_state_representation(state);
	if (r==null):
		return false;
	var _prev_state=_state_int;
	_state_int=r;
	if (state_changed_callback!=null && (_prev_state!=_state_int)):
		state_changed_callback.call(_state_int);
	return true;

func disable_callback():
	pass

func get_active_states():
	# returns all active states
	var arr=[];
	for i in range(len(_states)):
		if (check_if_state_is(_states[i])):
			arr.append(_states[i]);
	return arr;

func disable_state(state):
	var r=get_state_representation(state);
	if (r==null):
		return false;
	_state_int=(_state_int & ~r);
	return true;
	
func get_state_representation(state):
	# internal function to get int representation of single state
	var i=_states.find(state);
	if (i==-1):
		return null;
	return (0x1<<i);
	
func reset():
	# state_changed_callback=null;
	_state_int=0;

func reset_states():
	_states=[];

func change_state_int(state_int):
	if (_state_int!=state_int):
		_state_int=state_int;
		if (state_changed_callback!=null):
			state_changed_callback.call(_state_int);
