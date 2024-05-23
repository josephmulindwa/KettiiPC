extends TextureRect

var screen_bounds;
var wall_vector:Vector2=Vector2(1, 0);
var direction_vector:Vector2;
var collided:bool=false;
@export var rate_scalar:float=16.0;

func _ready():
	screen_bounds=get_viewport_rect().size;
	direction_vector=_generate_direction_vector();
	$Area2D.area_entered.connect(_on_flare_collided);

func _generate_direction_vector():
	var randx=randf_range(-1, 1);
	var randy=randf_range(-1, 1);
	while (absf(randx)==1): # no vertical or horizontal allowed
		randx=randf_range(-1, 1);
	while (absf(randy)==1):
		randy=randf_range(-1, 1);
	return Vector2(randx, randy);

func update_size(_size:Vector2):
	self.size=_size;
	_on_update_size();

func update_scale(_scale:Vector2):
	self.scale=_scale;
	_on_update_size();

func _on_update_size():
	# updates the collision object positions
	$Area2D.position=size/2.0;
	$Area2D/CollisionShape2D.position=Vector2.ZERO;

func get_wall_vector(area:Area2D):
	# uses the colliding area to detect the bouncing wall vector of the colliding area
	var dvector=$Area2D.global_position-area.global_position;
	var perpendicular=CoreUtils.get_perpendicular_vector(dvector);
	return CoreUtils.normalize_vector(perpendicular);

func _on_flare_collided(area:Area2D):
	if (area.is_in_group("flare")):
		collided=true;
		wall_vector=get_wall_vector(area);

func _process(delta):
	var update_vector=direction_vector*delta*rate_scalar;
	self.global_position=global_position+update_vector;
	
	var out_of_bounds_left=(global_position.x-(size.x*0))<=0;
	var out_of_bounds_right=(global_position.x+(size.x))>=screen_bounds.x;
	var out_of_bounds_top=(global_position.y-(size.y*0))<=0;
	var out_of_bounds_bottom=(global_position.y+(size.y))>=screen_bounds.y;
	
	if (collided):
		direction_vector=CoreUtils.get_reflection_vector(direction_vector, wall_vector);
		collided=false;
	elif (out_of_bounds_left || out_of_bounds_right):
		direction_vector=CoreUtils.get_reflection_vector(direction_vector, Vector2(0,1));
	elif (out_of_bounds_top || out_of_bounds_bottom):
		direction_vector=CoreUtils.get_reflection_vector(direction_vector, Vector2(1,0));
