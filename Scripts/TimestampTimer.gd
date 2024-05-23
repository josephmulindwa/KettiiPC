extends Node

var end_timestamp=null;
var running:bool=false;
var elapse_seconds=0; # the time the timer runs for
var elapse_callback=null;
var auto_follow_up:bool=false; # allows the timer to watch itself
var _callback_disabled:bool=false;
var _remaining_time_temp:float=0.0;

func set_elapse(_elapse:float):
	self.elapse_seconds=_elapse;
	
func get_elapse():
	return elapse_seconds;

func set_elapse_callback(_callback):
	self.elapse_callback=_callback;

func start(force:bool=false):
	"""
	starts timer with regards to current elapse 
	force : bool, default=false
		forces the timer to start regardless of state
	"""
	if (running && !force):
		return;
	var start_timestamp=Time.get_unix_time_from_system();
	end_timestamp=start_timestamp+elapse_seconds;
	_remaining_time_temp=elapse_seconds;
	_callback_disabled=false;
	running=true;

func is_running():
	return running;

func pause():
	running=false;
	
func stop(disable_callback=true):
	running=false;
	_callback_disabled=disable_callback; # set to disable callback as elapse is reached
	end_timestamp=Time.get_unix_time_from_system()-1;

func get_remaining_time()->float:
	""" returns the remaing elapse time"""
	if (!running):
		return _remaining_time_temp;
	var current_timestamp=Time.get_unix_time_from_system();
	if (current_timestamp>=end_timestamp):
		self.stop(false); # stop but allow callback
		if (!_callback_disabled && elapse_callback!=null):
			elapse_callback.call();
		_callback_disabled=true;
		return 0.0;
	_remaining_time_temp=end_timestamp-current_timestamp;
	return _remaining_time_temp;
	
func get_remaining_time_ratio():
	return (get_remaining_time()/elapse_seconds);

func _process(_delta):
	if (!auto_follow_up):
		return;
	get_remaining_time();
