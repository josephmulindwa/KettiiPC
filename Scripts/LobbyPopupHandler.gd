extends Node;

var panel_toggle_handler;

func _ready():
	self.visible=false;
	
	panel_toggle_handler=GameDataManager.ASSETS["toggle_manager"].new();
	panel_toggle_handler.name="PanelToggleHandler";
	add_child(panel_toggle_handler);
	panel_toggle_handler.item_list=[$NumberPlayersControl, $GameCodeInputControl, $RandomGameControl];
	panel_toggle_handler.enabled_callback=_on_panel_enabled;
	panel_toggle_handler.disabled_callback=_on_panel_disabled;
	
	Events.show_panel_lobby_popup.connect(_update_active_panel_visible);
	self.tree_exiting.connect(
		func(): GameUtils.free_items([panel_toggle_handler]);
	)

func _update_active_panel_visible(_index):
	if (_index==-1):
		self.visible=false;
		return;
	panel_toggle_handler.toggle_index(_index);
	self.visible=true;

func _on_panel_enabled(panel):
	panel.visible=true;

func _on_panel_disabled(panel):
	panel.visible=false;

