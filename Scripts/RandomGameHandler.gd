extends Control

func _ready():
	self.visible=false;
	var continue_button=$NinePatchPanel/ContinueButton;
	var close_button=$NinePatchPanel/CloseButton;
	
	Events.trigger_close_panel.connect(_on_close_panel);
	continue_button.pressed.connect(_on_start_random_session);
	close_button.pressed.connect(_on_close_panel);

func _on_start_random_session():
	Events.emit_signal("lobby_set_session_state", true);
	Events.emit_signal("show_panel_lobby_popup", -1);
	await MultiplayerConnectHandler.start_random();

func _on_close_panel():
	Parameter.PANEL_ACTIVE=false;
	Events.emit_signal("lobby_set_session_state", false);
	Events.emit_signal("show_panel_lobby_popup", -1);

func _notification(what):
	if (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		_on_close_panel();
