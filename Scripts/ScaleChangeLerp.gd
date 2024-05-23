extends TextureRect;

"""performs single scale lerp  form current ratio to end ratio"""
@export var end_ratio:float;
@export var scale_time_seconds:float;
@export var on_child:bool=false;
@export var destroy_on_finish:bool=true;

var tween;
var target;

func _ready():
	tween = create_tween();
	tween.set_loops(1);
	target=self;
	if(on_child):
		target=self.get_child(0);
	do_lerp();

func do_lerp():
	tween.tween_property(target, "scale", Vector2(end_ratio, end_ratio), scale_time_seconds);
	if (destroy_on_finish):
		tween.tween_callback(target.queue_free);
	
