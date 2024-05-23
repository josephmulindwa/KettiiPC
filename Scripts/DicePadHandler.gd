extends Control

@export var pad_id:int;
var scale_lerp_animation=null;

func _input(event):
	# check pause criteria
	if (!Parameter.GAME_READY || Parameter.GAME_PAUSED):
		return;
	var mouse_click=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT;
	if (event is InputEventScreenTouch || mouse_click):
		var clickable=$DicePad/DiceTouchPad;
		var rect=Rect2(clickable.position-clickable.position, clickable.size);
		if (rect.has_point(clickable.get_local_mouse_position())):
			if(Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.CPU):
				return;
			if(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE && Parameter.SELF_PLAYER_ID!=Parameter.CURRENT_PLAYER_ID):
				return;
			if(Parameter.STATE_HANDLER.check_if_state_is("AWAIT_ROLL")):
				Events.emit_signal("trigger_roll", [], false);
				if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
					Events.emit_signal("trigger_roll", [], true);
			elif(Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PAD_SELECT") && !Parameter.STATE.ROLLS_USED[pad_id]):
				Parameter.STATE.SELECTED_PAD_ID=pad_id;

func _ready():
	scale_lerp_animation=$DicePad/DicePointer;

func show_rounded_rect():
	$DicePad/DiceBoundRect.visible=true;
	
func hide_rounded_rect():
	$DicePad/DiceBoundRect.visible=false;

func _process(_delta):
	if (!Parameter.GAME_READY || Parameter.CURRENT_PLAYER_ID==null):
		return;
	var color = Parameter.PLAYER_COLORS[Parameter.CURRENT_PLAYER_ID];
	$DicePad/DiceBoundRect.self_modulate=color;
	if (Parameter.STATE.SELECTED_PAD_ID==self.pad_id || Parameter.STATE.SELECTED_PAD_ID==-1):
		show_rounded_rect();
	else:
		hide_rounded_rect();
		
	# handle dice pointer
	var is_table=(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.TABLE);
	var self_is_current_player=(Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID);
	if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_ROLL") && (is_table || self_is_current_player)):
		scale_lerp_animation.play_lerp();
		scale_lerp_animation.visible=true;
	else:
		scale_lerp_animation.pause_lerp();
		scale_lerp_animation.visible=false;

