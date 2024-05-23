extends Node

var close_button;
var ai_mode_toggle_button;
var blocking_toggle_button;
var sound_toggle_button;
var sound_toggle_label;
var speed_slider;
var defaults_button;
var min_move_step_time:float=0.1;
var max_move_step_time:float=0.5;

func _ready():
	self.visible=false;
	close_button=$OptionsPanel/CloseButton;
	ai_mode_toggle_button=$OptionsPanel/AIModeControl/ToggleButton;
	blocking_toggle_button=$OptionsPanel/BlockingControl/ToggleButton;
	sound_toggle_button=$OptionsPanel/SoundControl/ToggleButton;
	sound_toggle_label=$OptionsPanel/SoundControl/SoundLabel;
	speed_slider=$OptionsPanel/SliderContainer/SpeedSlider;
	defaults_button=$OptionsPanel/DefaultsButton;

	_render_options();
	if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
		var _sp=GameDataManager.CONFIGDATA.default_game_speed;
		GameDataManager.CONFIGDATA.set_game_speed(_sp);
		ai_mode_toggle_button.disabled=true;
		blocking_toggle_button.disabled=true;
		speed_slider.editable=false;
	
	Events.trigger_close_panel.connect(_on_close_button_pressed);
	Events.show_panel_settings.connect(
		func():
			Parameter.PANEL_ACTIVE=true;
			self.visible=true;
	);
	
	defaults_button.pressed.connect(_on_defaults_button_pressed);
	speed_slider.drag_ended.connect(_on_speed_slider_drag_ended);
	blocking_toggle_button.pressed.connect(_on_blocking_toggle_button_pressed);
	sound_toggle_button.pressed.connect(_on_sound_toggle_button_pressed);
	ai_mode_toggle_button.pressed.connect(_on_ai_mode_toggle_button_pressed);
	close_button.pressed.connect(_on_close_button_pressed);

func _render_options():
	speed_slider.min_value=1.0-_to_percentage(max_move_step_time);
	speed_slider.max_value=1.0-_to_percentage(min_move_step_time);
	speed_slider.step=0.1;
	speed_slider.value=1.0-_to_percentage(GameDataManager.CONFIGDATA.game_speed);

	if (GameDataManager.CONFIGDATA.ai_mode==Parameter.AI_MODE.SMART):
		ai_mode_toggle_button.button_pressed=true;
	else:
		ai_mode_toggle_button.button_pressed=false;
		
	if (GameDataManager.CONFIGDATA.sound_on):
		sound_toggle_button.button_pressed=true;
	else:
		sound_toggle_button.button_pressed=false;
	
	if (GameDataManager.CONFIGDATA.blocking_on):
		blocking_toggle_button.button_pressed=true;
	else:
		blocking_toggle_button.button_pressed=false;
	_update_sound_state_text();

func _to_percentage(val:float):
	# converts val to a percentage in reference to (min_move_time, max_move_time)
	var perc_float:float=(self.min_move_step_time-val)/(self.min_move_step_time-self.max_move_step_time);
	return perc_float*100;
	
func _from_percentage(perc:float):
	# converts perc to a value in reference to (min_move_time, max_move_time)
	perc=(1.0-perc);
	return self.min_move_step_time+(self.max_move_step_time-self.min_move_step_time)*(perc/100.0);
	
func _on_speed_slider_drag_ended(_value_changed:bool):
	GameDataManager.CONFIGDATA.set_game_speed(_from_percentage(speed_slider.value), true);
	
func _on_ai_mode_toggle_button_pressed():
	if (ai_mode_toggle_button.is_pressed()):
		GameDataManager.CONFIGDATA.ai_mode=Parameter.AI_MODE.SMART;
	else:
		GameDataManager.CONFIGDATA.ai_mode=Parameter.AI_MODE.SIMPLE;
		
func _on_sound_toggle_button_pressed():
	if (sound_toggle_button.is_pressed()):
		GameDataManager.CONFIGDATA.sound_on=true;
	else:
		GameDataManager.CONFIGDATA.sound_on=false;
	_update_sound_state_text();

func _on_blocking_toggle_button_pressed():
	if (blocking_toggle_button.is_pressed()):
		GameDataManager.CONFIGDATA.blocking_on=true;
	else:
		GameDataManager.CONFIGDATA.blocking_on=false;

func _update_sound_state_text():
	if (GameDataManager.CONFIGDATA.sound_on):
		sound_toggle_label.set_translate_key(0, "T_SOUND_ON");
		Events.emit_signal("pause_sound");
	else:
		sound_toggle_label.set_translate_key(0, "T_SOUND_OFF");

func _on_defaults_button_pressed():
	if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
		return;
	var language=GameDataManager.CONFIGDATA.language;
	var piece_type=GameDataManager.CONFIGDATA.piece_type;
	GameDataManager.clear_configdata();
	GameDataManager.CONFIGDATA.language=language;
	GameDataManager.CONFIGDATA.piece_type=piece_type;
	_render_options();

func _on_close_button_pressed():
	Parameter.PANEL_ACTIVE=false;
	Events.emit_signal("panel_settings_closed");
	self.visible=false;
