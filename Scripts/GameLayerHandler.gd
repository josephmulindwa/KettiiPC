extends CanvasLayer

var tutorials_layer=null;
var is_online=false;
var is_cpu;
var show_reward_btn:bool=false;

func _init():
	if(GameDataManager.CONFIGDATA==null):
		GameDataManager.read_configdata();
	if (GameDataManager.SAVEDATA==null):
		GameDataManager.read_savedata();
		
	is_cpu=(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.CPU);	
	is_online=(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE);

	Parameter.PLAYER_NAMES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, "T_COMPUTER");
	Parameter.PLAYER_TYPES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, Parameter.PLAYER_TYPE.NONE);
	Parameter.PLAYER_COMPLETION_PERCENTAGES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, 0);
	Parameter.PLAYER_COMPLETION_STATES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, false);
	Parameter.PLAYER_CONNECTION_STATES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, Parameter.CONNECTION_STATE.CONNECTED);

	# load location, percentages, completion statuses
	if (is_online):
		GameDataManager.SAVEDATA.active_player_index=0;
		GameDataManager.SAVEDATA.location_matrix=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS, Parameter.MAX_PIECES, 0);
		
		# extract names and ids - to be placed based on active states
		var enable_states=Parameter.PLAYER_ENABLE_STATES[GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS];
		var names=[];
		var ids=[]
		for ky in MultiplayerConnectHandler.player_names.keys():
			var kvalue=MultiplayerConnectHandler.player_names[ky];
			names.append(kvalue.alias);
			ids.append(kvalue.id);

		# assign the names, types
		var cnt=0;
		var start_id=-1;
		for i in range(Parameter.MAX_PLAYERS):
			if (!enable_states[i]):
				continue;
			if (start_id==-1):
				start_id=i;
			Parameter.PLAYER_NAMES[i]=names[cnt];#
			Parameter.PLAYER_TYPES[i]=Parameter.PLAYER_TYPE.HUMAN;
			if (ids[cnt]==MultiplayerConnectHandler.peer_id):
				Parameter.SELF_PLAYER_ID=i;
			cnt+=1;

		# set up mapping based on core id being server id; id of first player in game of N players
		GameDataManager.SAVEDATA.player_mapping=GameUtils.generate_mapping(GameDataManager.SAVEDATA.number_players, start_id);
	else:
		if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.CPU):
			Parameter.SELF_PLAYER_ID=GameDataManager.SAVEDATA.player_mapping[0];
		else:
			Parameter.SELF_PLAYER_ID=-1;
		var j=1;
		for k in range(GameDataManager.SAVEDATA.number_players):
			var _id=GameDataManager.SAVEDATA.player_mapping[k];
			if(_id==Parameter.SELF_PLAYER_ID || GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.TABLE): # or in OFFLINE-FRI
				Parameter.PLAYER_TYPES[_id] = Parameter.PLAYER_TYPE.HUMAN;
			else:
				Parameter.PLAYER_TYPES[_id] = Parameter.PLAYER_TYPE.CPU;
				
			if(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.TABLE):
				Parameter.PLAYER_NAMES[_id]="T_PLAYER_ENUM:"+str(j); # e.g T_PLAYER_ENUM:1
				j+=1;
			elif(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE && _id!=Parameter.SELF_PLAYER_ID):
				Parameter.PLAYER_NAMES[_id]="T_PLAYER_ENUM:"+str(j); # e.g T_PLAYER_ENUM:1
				j+=1;

func _ready():
	var settings_button=$SettingsButton;
	var back_button=$BackButton;
	
	if (is_online):
		$BoardSprite.set_script(load("res://Scripts/OnlineGameManager.gd"));
	else:
		$BoardSprite.set_script(load("res://Scripts/OfflineGameManager.gd"));
	$BoardSprite._ready();
	$BoardSprite.set_process(true);
	
	if (GameDataManager.is_new_game && !is_online): # show tutorial panel
		tutorials_layer=load("res://Prefabs/tutorials_layer.tscn").instantiate();
		pause_game();
		add_child(tutorials_layer);
		
	
	tree_exiting.connect(func() : Events.emit_signal("pause_sound"));
	Events.panel_piece_type_closed.connect(_on_piece_type_panel_closed);
	Events.panel_game_over_closed.connect(_on_game_over_panel_closed);
	Events.panel_six_roll_disabled.connect(_on_six_roll_panel_closed);
	Events.panel_settings_closed.connect(_on_panel_settings_closed);
	Events.hide_menu_panel.connect(_on_hide_tutorials_panel);
	
	settings_button.pressed.connect(_on_settings_button_pressed);
	back_button.pressed.connect(_on_back_button_pressed);

func get_random_wait_time(start=36, end=105):
	return randf_range(start, end);

func pause_game():
	Parameter.GAME_PAUSED=true;
	Events.emit_signal("pause_sound");

func resume_game():
	Parameter.GAME_PAUSED=false;

func _on_hide_tutorials_panel(_args):
	tutorials_layer.visible=false;
	tutorials_layer.queue_free();
	resume_game();

func _on_six_roll_panel_closed():
	resume_game();

func _on_panel_settings_closed():
	if (GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.ONLINE):
		GameDataManager.write_current_configdata();
	resume_game();

func _on_piece_type_panel_closed():
	GameDataManager.write_current_configdata();
	resume_game();

func _on_game_over_panel_closed():
	resume_game();

func _on_settings_button_pressed():
	pause_game();
	Events.emit_signal("show_panel_settings");

func _on_back_button_pressed():
	if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
		MultiplayerConnectHandler.reset_networking();
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn");

func get_player_completion_listing():
	return $BoardSprite.player_completion_listing;
