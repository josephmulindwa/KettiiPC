extends Node

signal back_pressed(context);

signal show_panel_exit;
signal show_panel_settings;
signal show_panel_piece_type;
signal show_panel_six_roll;
signal show_panel_game_over;
signal show_panel_lobby;
signal show_panel_lobby_popup(id);
signal hide_menu_panel(panelname);
signal trigger_close_panel; # used to trigger panel close for any panel
signal close_panel_lobby_popup(new_session_state);

signal panel_piece_type_closed;
signal panel_game_over_closed;
signal panel_settings_closed;
signal panel_six_roll_disabled;
signal panel_disabled;

signal update_completion_listing;

signal lobby_scene_back_pressed;
signal lobby_set_session_state(state);

signal play_sound(sound_id);
signal pause_sound;

signal trigger_roll(presets, rpc);
signal trigger_reset_roll;

func _ready():
	name="Events";
