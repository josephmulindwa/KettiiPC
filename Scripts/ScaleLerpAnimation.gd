extends Node;
@export var min_ratio:float;
@export var max_ratio:float;
@export var scale_time_seconds:float;
@export var on_child:bool=false;
@export var reversed:bool=false;
@export var repeated:bool=true;

var running:bool=false;

var tween;
var target;

func _ready():
	tween = create_tween();
	if (repeated):
		tween.set_loops(-1);
	else:
		tween.set_loops(1);
	target=self;
	if(on_child):
		target=self.get_child(0);
	do_lerp();

func do_lerp():
	if (self.running):
		return;
	self.running=true;
	var start_scale=min_ratio;
	var end_scale=max_ratio;
	if (reversed):
		start_scale=max_ratio;
		end_scale=min_ratio;
	tween.tween_property(target, "scale", Vector2(start_scale, start_scale), scale_time_seconds);
	tween.tween_property(target, "scale", Vector2(end_scale, end_scale), scale_time_seconds);

func pause_lerp():
	if (!self.running):
		return;
	self.running=false;
	tween.pause();

func play_lerp():
	if (self.running):
		return;
	self.running=true;
	tween.play();

