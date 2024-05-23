extends Node

var number_players_toggle_handler;
var toggle_key_map;

func _ready():
	var continue_button=$NinePatchPanel/ContinueButton;
	var close_button=$NinePatchPanel/CloseButton;
	number_players_toggle_handler=GameDataManager.ASSETS["toggle_manager"].new();
	number_players_toggle_handler.item_list=[
		$NinePatchPanel/CheckBoxParent_2/CheckBox,
		$NinePatchPanel/CheckBoxParent_3/CheckBox,
		$NinePatchPanel/CheckBoxParent_4/CheckBox
	];
	for i in range(len(number_players_toggle_handler.item_list)):
		number_players_toggle_handler.item_list[i].pressed.connect(
			func():
				number_players_toggle_handler.toggle_index(i);
				number_players_toggle_handler.item_list[i].button_pressed=true;
		)
	Events.trigger_close_panel.connect(_on_close_panel);
	number_players_toggle_handler.enabled_callback=_on_checkbox_enabled;
	number_players_toggle_handler.disabled_callback=_on_checkbox_disabled;
	number_players_toggle_handler.toggle_index(GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS);
	continue_button.pressed.connect(_on_continue_button_pressed);
	close_button.pressed.connect(_on_close_panel);
	self.tree_exiting.connect(
		func(): GameUtils.free_items([number_players_toggle_handler]);
	)
	
func _on_checkbox_enabled(checkbox):
	var idx=0;
	for i in range(len(number_players_toggle_handler.item_list)):
		if (number_players_toggle_handler.item_list[i]==checkbox):
			idx=i;
			break;
	GameDataManager.SAVEDATA.number_players=Parameter.MIN_PLAYERS+idx;
	checkbox.button_pressed=true;
	
func _on_checkbox_disabled(checkbox):
	checkbox.button_pressed=false;

func _on_continue_button_pressed():
	Events.emit_signal("lobby_set_session_state", true);
	Events.emit_signal("show_panel_lobby_popup", -1);
	await MultiplayerConnectHandler.start_server();

func _on_close_panel():
	Parameter.PANEL_ACTIVE=false;
	Events.emit_signal("lobby_set_session_state", false);
	Events.emit_signal("show_panel_lobby_popup", -1);

func _notification(what):
	if (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		_on_close_panel();
