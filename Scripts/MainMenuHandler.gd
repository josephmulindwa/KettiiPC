extends CanvasLayer

var main_menu_context:bool=true; # governs if game is in main_menu or new_game context
var context_states={};
var active_button_index:int=0;
var previous_active_button_index:int=-1;
var has_resumable_save:bool=false;
var config_subscene=null;
var lobby_subscene=null;
var board_texture;
var button_list=[];
var button_highlight_element;

var logout_button;
var back_button;

func _init():
	_initialize_statehandler();
	GameDataManager.read_savedata();
	GameDataManager.read_configdata();

func _initialize_statehandler():
	if (Parameter.STATE_HANDLER==null):
		Parameter.STATE_HANDLER=GameDataManager.ASSETS["state_handler"].new();
		Parameter.add_child(Parameter.STATE_HANDLER);
		Parameter.STATE_HANDLER.name="ParameterStateHandler";
		Parameter.STATE_HANDLER.add_states(
			["START_CYCLE","AWAIT_ROLL","ROLLED","AWAIT_PAD_SELECT","AWAIT_PIECE_SELECT","MOVING","REACHED_HOME","END_CYCLE"]
		);
		Parameter.STATE_HANDLER.state_changed_callback=func(state): Parameter.STATE.STATE=state;
	if (Parameter.CYCLE_TIMER_OBJECT==null):
		Parameter.CYCLE_TIMER_OBJECT=GameDataManager.ASSETS["timestamp_timer"].new();
		Parameter.add_child(Parameter.CYCLE_TIMER_OBJECT);
		Parameter.CYCLE_TIMER_OBJECT.name="CycleTimerObject";
	Parameter.reset_cycle();

func _ready():
	get_tree().set_quit_on_go_back(false); # disable back button
	Parameter.reset_game_state();
	MultiplayerConnectHandler.reset_networking();
	update_version_text();
	
	board_texture=$RPanel/BoardWork;
	button_highlight_element=$ButtonHighlightElement;
	logout_button=$LPanel/EscButtonsControl/ExitButton;
	back_button=$LPanel/EscButtonsControl/BackButton;
	button_list=[$LPanel/ButtonI, $LPanel/ButtonII, $LPanel/ButtonIII];
	
	context_states={
		"main_menu":["T_NEW_GAME", "T_RESUME", "T_SETTINGS"],
		"new_game":["T_COMPUTER", "T_TURNS", "T_LAN"]
	};
	has_resumable_save=(GameDataManager.SAVEDATA.loaded==true);
	_update_active_button_render();
	
	logout_button.pressed.connect(_on_exit_button_pressed);
	back_button.pressed.connect(_on_back_button_pressed);
	
	for i in range(len(button_list)):
		button_list[i].pressed.connect(
			func(): _on_button_event_requested(i);
		);
		button_list[i].mouse_entered.connect(
			func(): _on_mouse_entered_button_area(i);
		);
	
	if (Parameter.RIM_PIECE_PREFABS==null || len(Parameter.RIM_PIECE_PREFABS)!=Parameter.MAX_PLAYERS+1):
		Parameter.RIM_PIECE_PREFABS=[
			GameDataManager.ASSETS["red_rim_piece"],
			GameDataManager.ASSETS["blue_rim_piece"],
			GameDataManager.ASSETS["yellow_rim_piece"],
			GameDataManager.ASSETS["green_rim_piece"],
			GameDataManager.ASSETS["any_rim_piece"]
		];
	
	if (Parameter.CONE_PIECE_PREFABS==null || len(Parameter.CONE_PIECE_PREFABS)!=Parameter.MAX_PLAYERS+1):
		Parameter.CONE_PIECE_PREFABS=[
			GameDataManager.ASSETS["red_cone_piece"],
			GameDataManager.ASSETS["blue_cone_piece"],
			GameDataManager.ASSETS["yellow_cone_piece"],
			GameDataManager.ASSETS["green_cone_piece"],
			GameDataManager.ASSETS["any_cone_piece"]
		];

func update_version_text():
	var version_label=$LPanel/VersionControl/Label;
	version_label.set_enumeration_bind(Parameter.VERSION_NUMBER);

func _on_new_game_button_pressed():
	for i in range(len(context_states["new_game"])):
		var button_tkey=context_states["new_game"][i];
		var btn=button_list[i];
		btn.get_child(0).set_translate_key(0, button_tkey);
	main_menu_context=false;
	_on_computer_button_pressed();

func _on_computer_button_pressed():
	if (config_subscene==null):
		config_subscene=load("res://Scenes/config_subscene.tscn").instantiate();
		$RPanel.add_child(config_subscene);
	if (lobby_subscene!=null):
		lobby_subscene.visible=false;
	GameDataManager.SAVEDATA.active_game_mode=Parameter.GAME_MODE.CPU;
	_initialize_config_player_state();
	config_subscene.visible=true;

func _on_resume_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn");

func _on_turns_button_pressed():
	if (config_subscene==null):
		config_subscene=load("res://Scenes/config_subscene.tscn").instantiate();
		$RPanel.add_child(config_subscene);
	if (lobby_subscene!=null):
		lobby_subscene.visible=false;
	GameDataManager.SAVEDATA.active_game_mode=Parameter.GAME_MODE.TABLE;
	_initialize_config_player_state();
	config_subscene.visible=true;

func _initialize_config_player_state():
	GameDataManager.SAVEDATA.number_players=Parameter.MAX_PLAYERS;
	Parameter.SELF_PLAYER_ID=0;
	GameDataManager.SAVEDATA.active_player_index=0;
	
func _on_settings_button_pressed():
	Events.emit_signal("show_panel_settings");

func _on_lan_button_pressed():
	if (lobby_subscene==null):
		lobby_subscene=load("res://Scenes/lobby_subscene.tscn").instantiate();
		$RPanel.add_child(lobby_subscene);
	if (config_subscene!=null):
		config_subscene.visible=false;
	GameDataManager.SAVEDATA.active_game_mode=Parameter.GAME_MODE.TABLE;
	lobby_subscene.visible=true;

func _on_exit_button_pressed():
	Events.emit_signal("show_panel_exit");
	previous_active_button_index=-1;

func _on_back_button_pressed():
	if (config_subscene!=null):
		config_subscene.visible=false;
	if (lobby_subscene!=null):
		lobby_subscene.visible=false;
		Events.emit_signal('lobby_scene_back_pressed');
		
	for i in range(len(context_states["main_menu"])):
		var button_tkey=context_states["main_menu"][i];
		var btn=button_list[i];
		btn.get_child(0).set_translate_key(0, button_tkey);
	main_menu_context=true;
	previous_active_button_index=-1;

func _notification(what):
	if (what==NOTIFICATION_WM_CLOSE_REQUEST):
		GameUtils.on_exit_game();
	elif (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		if (Parameter.PANEL_ACTIVE):
			Events.emit_signal("trigger_close_panel");
			return;
		Events.emit_signal("show_panel_exit");

func _update_active_button_render():
	var selectable_tint=Color("FFFFFF");
	var unselectable_tint=Color("888888"); # 499BAE

	if (active_button_index!=previous_active_button_index):
		for i in range(len(button_list)):
			if (i==1):
				if (main_menu_context && !has_resumable_save):
					button_list[i].modulate=unselectable_tint;
					continue;
				else:
					button_list[i].modulate=selectable_tint;
				
			if(i==active_button_index):
				var highlight_element_parent=button_highlight_element.get_parent();
				if (highlight_element_parent!=null):
					highlight_element_parent.remove_child(button_highlight_element);
				button_list[i].add_child(button_highlight_element);
				button_highlight_element.global_position=button_list[i].global_position;
				button_highlight_element.anchors_preset=Control.PRESET_CENTER;
				button_highlight_element.visible=true;
		previous_active_button_index=active_button_index;

func _on_button_event_requested(button_index):
	if (button_index==1 && main_menu_context && !has_resumable_save):
		return;
	else:
		active_button_index=button_index;
	_button_event_callback();
	
func _on_mouse_entered_button_area(button_index):
	if (button_index==1 && main_menu_context && !has_resumable_save):
		return;
	active_button_index=button_index; # trigger highlight
	if (!main_menu_context):
		_on_button_event_requested(button_index);

func _button_event_callback():
	# reacts to the active button index action;
	if (active_button_index==0): # new_game, computer
		if (main_menu_context):
			_on_new_game_button_pressed();
		else:
			_on_computer_button_pressed();
	elif (active_button_index==1): # resume, turns
		if (main_menu_context):
			_on_resume_button_pressed();
		else:
			_on_turns_button_pressed();
	elif (active_button_index==2):
		if(main_menu_context):
			_on_settings_button_pressed();
		else:
			_on_lan_button_pressed();
	previous_active_button_index=-1;

func _process(_delta):
	#board_texture.visible=main_menu_context;
	_update_active_button_render();
	logout_button.visible=(main_menu_context);
	back_button.visible=!(main_menu_context);

# reset lobby when another button pressed
