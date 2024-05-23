extends Control

class_name Piece;

var player_id:int;
var piece_id:int;
var piece_marker_ratio=1.3;
var inner=null;
var piece_marker_control=null;
var tile_parent=null;

func _input(event):
	if (!Parameter.GAME_READY || Parameter.GAME_PAUSED):
		return;
	var mouse_click=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT;
	if (event is InputEventScreenTouch || mouse_click):
		var clickable_rect=$ClickableRect;
		var rect=Rect2(clickable_rect.position-clickable_rect.position, clickable_rect.size);
		if (rect.has_point(clickable_rect.get_local_mouse_position())):
			if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PIECE_SELECT") && piece_marker_control!=null):
				Parameter.STATE_HANDLER.disable_state("AWAIT_PAD_SELECT");
				Parameter.STATE.MOVING_PLAYER_ID=self.player_id;
				Parameter.STATE.MOVING_PIECE_ID=self.piece_id;

func _ready():
	inner=$ColorPiece;

func set_piece_size(_size:Vector2):
	var final_scale=Vector2(_size.x/inner.size.x, _size.y/inner.size.y);
	set_scale(final_scale);

func get_piece_size():
	return get_node("ColorPiece").size;

func add_marker():
	if(piece_marker_control!=null):
		return;
	var min_size=min(inner.size.x, inner.size.y);
	piece_marker_control=GameDataManager.ASSETS["piece_marker_effect"].instantiate();
	add_child(piece_marker_control);
	move_child(piece_marker_control, 0);
	var piece_marker=piece_marker_control.get_child(0);
	var scaling=min_size/min(piece_marker.size.x, piece_marker.size.y)
	piece_marker_control.scale=Vector2(scaling, scaling)*1.06;

func remove_marker():
	if(piece_marker_control==null):
		return;
	piece_marker_control.queue_free();
	piece_marker_control=null;

func start_after_effect():
	if (tile_parent==null):
		return;
	var after_image=GameDataManager.ASSETS["piece_after_effect"].instantiate();
	tile_parent.inner.add_child(after_image);
	var min_size=min(inner.size.x, inner.size.y);
	var scaling=min_size/min(after_image.size.x, after_image.size.y)
	after_image.scale=Vector2(scaling, scaling)*0.9;
	after_image.scale_time_seconds=GameDataManager.CONFIGDATA.game_speed;
	after_image.self_modulate=Parameter.PLAYER_COLORS[self.player_id];
	after_image.self_modulate.a=0.7;

func start_explosion_effect():
	if (tile_parent==null):
		return;
	var explosion_image=GameDataManager.ASSETS["piece_explosion_effect"].instantiate();
	tile_parent.inner.add_child(explosion_image);
	var min_size=min(inner.size.x, inner.size.y);
	var scaling=min_size/min(explosion_image.size.x, explosion_image.size.y)
	explosion_image.scale=Vector2(scaling, scaling)*1.0;
	explosion_image.self_modulate = Parameter.PLAYER_COLORS[self.player_id];
	explosion_image.scale_time_seconds=GameDataManager.CONFIGDATA.game_speed;

func _process(_delta):
	if (!Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PAD_SELECT") && !Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PIECE_SELECT")):
		remove_marker();
