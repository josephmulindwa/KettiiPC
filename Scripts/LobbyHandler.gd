extends Control

func _ready():
	Events.lobby_scene_back_pressed.connect(_on_back_button_pressed);
	Parameter.SELF_PLAYER_ID=-1;
	GameDataManager.SAVEDATA.number_players=Parameter.MIN_PLAYERS;

func _on_back_button_pressed():
	MultiplayerConnectHandler.reset_networking();
	MultiplayerConnectHandler.reset_state();

func _notification(what):
	if (what==NOTIFICATION_WM_CLOSE_REQUEST):
		GameUtils.on_exit_game();
	elif (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		if (Parameter.PANEL_ACTIVE):
			Events.emit_signal("trigger_close_panel");
			return;
		_on_back_button_pressed();
