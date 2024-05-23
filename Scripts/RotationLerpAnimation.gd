extends Node;
@export var min_degree:float;
@export var max_degree:float;
@export var rotation_time_seconds:float;
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
	var start_degree=min_degree;
	var end_degree=max_degree;
	if (reversed):
		start_degree=max_degree;
		end_degree=min_degree;
	tween.tween_property(target, "rotation_degrees", start_degree, rotation_time_seconds);
	tween.tween_property(target, "rotation_degrees", end_degree, rotation_time_seconds);

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

