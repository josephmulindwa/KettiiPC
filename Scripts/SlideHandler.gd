extends Node

"""
class for scrolling objects; all objects remain in memory
scrolls objects so that the [next] object replaces the [current] one
"""
@export var horizontal:bool=true;
@export var slide_speed:float=1.0;
var _sliding:bool=false;
var items:Array;
var forward:bool=true;
var active_index=0;
var tween;
var slide_started_callback=null;
var slide_ended_callback=null;

func is_sliding():
	return _sliding;

func _on_slide_started():
	_sliding=true;
	if (slide_started_callback!=null):
		slide_started_callback.call();

func _on_slide_ended():
	_sliding=false;
	if (slide_ended_callback!=null):
		slide_ended_callback.call();

func perform_slide():
	# performs a pseudo slide animation
	if (len(items)<2):
		return;
	if (forward && active_index>=len(items)-1):
		return;
	if (!forward && active_index<=0):
		return;
	if (_sliding):
		return;
	_on_slide_started();
	tween = create_tween();
	tween.finished.connect(_on_slide_ended);
	tween.set_parallel(true);
	var d=items[1].global_position-items[0].global_position; # determinant is first pair only
	if (!forward):
		d*=-1;
		
	for i in range(len(items)):
		var item=items[i];
		if (horizontal):
			var new_pos=item.global_position-Vector2(d.x, 0);
			tween.tween_property(item, "global_position", new_pos, slide_speed);
		else:
			var new_pos=item.global_position-Vector2(0, d.y);
			tween.tween_property(item, "global_position", new_pos, slide_speed);
	tween.play();
	if (forward):
		active_index+=1;
	else:
		active_index-=1;
	
