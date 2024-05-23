extends Node

var game_code_input_field;
var warn_label;

func _ready():
	var continue_button=$NinePatchPanel/ContinueButton;
	var close_button=$NinePatchPanel/CloseButton;
	game_code_input_field=$NinePatchPanel/GameCodeFieldParent/GameCodeField;
	warn_label=$NinePatchPanel/WarnLabel;
	warn_label.set_translate_key(0, "");
	continue_button.pressed.connect(_on_continue_button_pressed);
	close_button.pressed.connect(_on_close_panel);
	
	var placeholder_text="";
	for i in range(MultiplayerConnectHandler.GAME_CODE_SIZE):
		placeholder_text+="-";
	game_code_input_field.placeholder_text=placeholder_text;
	game_code_input_field.text_changed.connect(_on_text_changed);
	
	Events.trigger_close_panel.connect(_on_close_panel);

func _on_text_changed():
	game_code_input_field.text=game_code_input_field.text.to_upper();
	warn_label.set_translate_key(0, "");
	game_code_input_field.text=game_code_input_field.text.left(MultiplayerConnectHandler.GAME_CODE_SIZE);
	game_code_input_field.set_caret_column(len(game_code_input_field.text));

func _on_continue_button_pressed():
	var game_code=game_code_input_field.text;
	if (len(game_code)!=MultiplayerConnectHandler.GAME_CODE_SIZE):
		warn_label.set_translate_key(0, "T_INVALID_GAME_CODE");
		return;
	if (!CoreUtils.is_clean_string(game_code)):
		warn_label.set_translate_key(0, "T_INVALID_GAME_CODE");
		return;
	MultiplayerConnectHandler.game_code=game_code;
	Events.emit_signal("lobby_set_session_state", true);
	_hide_panel_procedure();
	await MultiplayerConnectHandler.connect_to_server(MultiplayerConnectHandler.game_code);
	
func _hide_panel_procedure():
	Events.emit_signal("show_panel_lobby_popup", -1);
	game_code_input_field.text=""; # reset game code field

func _on_close_panel():
	Parameter.PANEL_ACTIVE=false;
	Events.emit_signal("lobby_set_session_state", false);
	_hide_panel_procedure();

func _notification(what):
	if (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		_on_close_panel();
