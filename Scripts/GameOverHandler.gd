extends Node

var close_button;
var number_players:int;
var player_mapping;
var disconnect_visibility_timer;
var player_disconnected_indicator;
var player_list_items:Array;
var completion_listing:Array;

func _ready():
	self.visible=false;
	close_button=$GameOverPanel/CloseButton;
	var main_menu_button=$GameOverPanel/MainMenuButton;
	player_disconnected_indicator=$GameOverPanel/PlayerDisconnectedTint;
	player_list_items=[
		$GameOverPanel/PlayerListItem1,
		$GameOverPanel/PlayerListItem2,
		$GameOverPanel/PlayerListItem3,
		$GameOverPanel/PlayerListItem4
	];
	number_players=GameDataManager.SAVEDATA.number_players;
	player_mapping=GameDataManager.SAVEDATA.player_mapping;
	
	disconnect_visibility_timer=Timer.new();
	add_child(disconnect_visibility_timer);
	disconnect_visibility_timer.wait_time=5.0;
	disconnect_visibility_timer.one_shot=true;
	disconnect_visibility_timer.timeout.connect(
		func() : 
			player_disconnected_indicator.visible=false
			disconnect_visibility_timer.queue_free();
	);
	
	Events.show_panel_game_over.connect(_show_panel_game_over);
	Events.update_completion_listing.connect(_on_completion_listing_updated);
	
	close_button.pressed.connect(self._on_close_button_pressed);
	main_menu_button.pressed.connect(self._on_main_menu_button_pressed);

func _show_panel_game_over():
	if(self.visible):
		return;
	close_button.visible=(!Parameter.GAME_COMPLETED); # give player option to exit
	player_disconnected_indicator.visible=false;
	if (GameDataManager.SAVEDATA.number_players==1):
		player_disconnected_indicator.visible=true;
		disconnect_visibility_timer.start();
		# play a different sound
	else:
		Events.emit_signal("play_sound", "GAME_OVER");
	_fill_player_list();
	self.visible=true;
	
func _on_completion_listing_updated(listing):
	self.completion_listing=listing;

func _on_close_button_pressed():
	Events.emit_signal("panel_game_over_closed");
	Parameter.PANEL_ACTIVE=false;
	self.visible=false;

func _on_main_menu_button_pressed():
	GameDataManager.clear_savedata();
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn");

func _fill_player_list():
	var percentage_sorted_listing=[];
	for i in range(number_players):
		var _id=player_mapping[i];
		if (true): # check if still connected if in online
			var idx=completion_listing.find(_id);
			if (idx==-1):
				idx=Parameter.MAX_PLAYERS;
			idx=Parameter.MAX_PLAYERS-idx;
			percentage_sorted_listing.append([idx, Parameter.PLAYER_COMPLETION_PERCENTAGES[_id], _id]);
	# sort available players by cpmpletion_listing && percentage of completion
	percentage_sorted_listing.sort_custom(func(a, b): return (a>b));

	for i in range(Parameter.MAX_PLAYERS):
		player_list_items[i].visible=false;

	for i in range(len(percentage_sorted_listing)):
		var item=player_list_items[i];
		var _player_id=percentage_sorted_listing[i][2];
		item.set_player_id(_player_id);
		item.set_rank(i+1);
		# constructing name text
		var _name=Parameter.PLAYER_NAMES[_player_id];
		var name_translate=GameUtils.get_translated(_name, GameDataManager.CONFIGDATA.language);
		if (name_translate==null):
			name_translate=_name;
		item.visible=true;
	return;
