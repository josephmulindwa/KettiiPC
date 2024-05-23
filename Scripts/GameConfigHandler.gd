extends Control

var selectable_controls:Array;
var number_pieces_changed=true;
var _updating_piece_render:bool=false;
var _queue_freeables=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, null);

func _input(event):
	var mouse_click=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT;
	if (event is InputEventScreenTouch || mouse_click):
		var rect;
		# color pick click detection
		var idx=0;
		for i in range(len(self.selectable_controls)):
			# if not disabled
			var color_enabled=Parameter.PLAYER_ENABLE_STATES[GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS][i];
			if (!color_enabled):
				continue;
			var clickable=self.selectable_controls[i].get_node("SelectionRect");
			rect = Rect2(Vector2(0, 0), clickable.size); 
			if (rect.has_point(clickable.get_local_mouse_position())):
				if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.CPU):
					Parameter.SELF_PLAYER_ID=i;
					GameDataManager.SAVEDATA.active_player_index=idx;
					idx+=1;
				break;

func _ready():
	get_tree().set_quit_on_go_back(false); # disable back button

	if (GameDataManager.CONFIGDATA==null):
		GameDataManager.read_configdata();
	var game_mode=GameDataManager.SAVEDATA.active_game_mode;
	GameDataManager.reset_savedata();
	GameDataManager.SAVEDATA.active_game_mode=game_mode;
	GameDataManager.SAVEDATA.number_players=Parameter.MAX_PLAYERS;
	Parameter.SELF_PLAYER_ID=0;
	GameDataManager.SAVEDATA.active_player_index=0;

	self.selectable_controls = [
		$ElementControl/RoundedRectControl/RoundRect/RedControl,
		$ElementControl/RoundedRectControl/RoundRect/BlueControl,
		$ElementControl/RoundedRectControl/RoundRect/YellowControl,
		$ElementControl/RoundedRectControl/RoundRect/GreenControl
	];
	
	var play_button=$ElementControl/PlayButtonControl/Button;
	var arrow_left_button=$ElementControl/NumberPlayersLabelControl/ArrowLeftButton;
	var arrow_right_button=$ElementControl/NumberPlayersLabelControl/ArrowRightButton;
	#var pieces_button=$PiecesButton;
	
	play_button.pressed.connect(self._on_play_button_pressed);
	arrow_left_button.pressed.connect(self._on_arrow_left_button_pressed);
	arrow_right_button.pressed.connect(self._on_arrow_right_button_pressed);
	#pieces_button.pressed.connect(self._on_piece_type_select_button_pressed);
	
	_update_number_players_text();
	_update_piece_render();
	self.tree_exiting.connect(
		func(): GameUtils.free_items(_queue_freeables);
	);
	
func _update_piece_render():
	# updates pieces to current type
	_updating_piece_render=true;
	var piece_type=GameDataManager.CONFIGDATA.piece_type;
	for i in range(len(self.selectable_controls)):
		var control=self.selectable_controls[i];
		var old_piece=control.get_node("PieceParent");
		if (old_piece!=null):
			control.remove_child(old_piece);
			old_piece.queue_free();
		var piece;
		if (piece_type==Parameter.PIECE_TYPE.RIM):
			piece=Parameter.RIM_PIECE_PREFABS[i].instantiate();
			control.add_child(piece);
			piece.scale=Vector2(3.4, 3.4);
		elif (piece_type==Parameter.PIECE_TYPE.CONE):
			piece=Parameter.CONE_PIECE_PREFABS[i].instantiate();
			control.add_child(piece);
			piece.scale=Vector2(2.0, 2.0);
		_queue_freeables[i]=piece;
	_updating_piece_render=false;

func _update_number_players_text():
	var number_players_label=$ElementControl/NumberPlayersLabelControl/NumberPlayersLabel;
	var translate_key="T_"+str(GameDataManager.SAVEDATA.number_players)+"_PLAYERS";
	var translate_keys:Array[String]=[translate_key];
	number_players_label.set_translate_keys(translate_keys);
	
func _on_play_button_pressed():
	GameDataManager.write_current_configdata(); # saves on play
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn");

func _on_arrow_left_button_pressed():
	self.number_pieces_changed=true;
	GameDataManager.SAVEDATA.number_players-=1;
	if (GameDataManager.SAVEDATA.number_players<Parameter.MIN_PLAYERS):
		GameDataManager.SAVEDATA.number_players=Parameter.MIN_PLAYERS;

func _on_arrow_right_button_pressed():
	self.number_pieces_changed=true;
	GameDataManager.SAVEDATA.number_players+=1;
	if (GameDataManager.SAVEDATA.number_players>Parameter.MAX_PLAYERS):
		GameDataManager.SAVEDATA.number_players=Parameter.MAX_PLAYERS;

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn");
	
func _on_piece_type_select_button_pressed():
	Events.emit_signal("show_panel_piece_type");

func _notification(what):
	if (what==NOTIFICATION_WM_CLOSE_REQUEST):
		GameUtils.on_exit_game();
	elif (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		if (Parameter.PANEL_ACTIVE):
			Events.emit_signal("trigger_close_panel");
			return;
		_on_back_button_pressed();

func _process(_delta):
	# set self id to an enabled color
	var states_idx=GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS;
	if (!Parameter.PLAYER_ENABLE_STATES[states_idx][Parameter.SELF_PLAYER_ID]):
		for i in range(Parameter.MAX_PLAYERS):
			if (Parameter.PLAYER_ENABLE_STATES[states_idx][i] && self.number_pieces_changed):
				Parameter.SELF_PLAYER_ID=i;
				break;
	GameDataManager.SAVEDATA.player_mapping=GameUtils.generate_mapping(GameDataManager.SAVEDATA.number_players, Parameter.SELF_PLAYER_ID);
	# update render by type
	_update_number_players_text();
	if (GameDataManager.CONFIGDATA.piece_type_changed):
		_update_piece_render();
		GameDataManager.CONFIGDATA.piece_type_changed=false;
	
	# update visuals
	if (!_updating_piece_render):
		for i in range(len(self.selectable_controls)):
			var piece=self.selectable_controls[i].get_node("PieceParent");
			var selection_rect=self.selectable_controls[i].get_node("SelectionRect");
			var color_enabled=Parameter.PLAYER_ENABLE_STATES[GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS][i];
			piece.visible=color_enabled;
			selection_rect.visible=(i==Parameter.SELF_PLAYER_ID && GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.CPU);
	
	self.number_pieces_changed=false; # reset to default
