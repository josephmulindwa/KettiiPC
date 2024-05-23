extends Node

var status_label;
var notice_label;
var player_name="";
var default_status_translate_key="T_SELECT_AN_OPTION";
var option_button;
var previous_button;
var next_button;

var option_id=0;
var option_translate_keys:Array;
var option_messages:Array;
var current_state;
var session_active:bool=false;
var changing_state:bool=false;

var max_session_time=80; # seconds
var session_timer;

# Called when the node enters the scene tree for the first time.
func _ready():
	status_label=$StatusLabel;
	notice_label=$NoticeLabel;
	option_button=$OptionButton;
	previous_button=$OptionControl/ArrowLeftButton;
	next_button=$OptionControl/ArrowRightButton;
	
	option_translate_keys=["T_INVITE", "T_JOIN", "T_RANDOM"];
	option_messages=["T_INVITE_OTHER_PLAYERS", "T_JOIN_GAME", "T_JOIN_A_RANDOM_PLAYER"];
	
	Events.lobby_set_session_state.connect(_on_lobby_set_session_state);
	
	option_button.pressed.connect(_on_options_button_pressed);
	previous_button.pressed.connect(_on_previous_button_pressed);
	next_button.pressed.connect(_on_next_button_pressed);
	
	session_timer=GameDataManager.ASSETS["timestamp_timer"].new();
	session_timer.name="SessionTimer";
	add_child(session_timer);
	session_timer.set_elapse(max_session_time);
	session_timer.auto_follow_up=true;
	session_timer.elapse_callback=_on_timer_finish;
	
	GameDataManager.SAVEDATA.number_players=Parameter.MIN_PLAYERS;
	MultiplayerConnectHandler.reset_state();
	MultiplayerConnectHandler.on_peers_connected_callback=_on_all_peers_connected;
	MultiplayerConnectHandler.update_status.connect(_on_receive_network_update);
	
	self.tree_exiting.connect(
		func(): GameUtils.free_items([session_timer]);
	);

func _on_lobby_set_session_state(state):
	session_active=state;
	if (state):
		start_session_timer();
		_set_option_button_text("T_CANCEL");
	else:
		_reset_lobby_state(false);

func _set_option_button_text(s:String):
	option_button.get_child(0).set_translate_key(0, s);

func _update_player_list():
	# updates player list
	var keys=MultiplayerConnectHandler.player_names.keys();
	Parameter.PLAYER_NAMES=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, "");
	for i in range(Parameter.MAX_PLAYERS):
		var item_name="PlayerListItem"+str(i+1);
		var item=$PlayerListPanel.get_node(item_name);
		if (i<len(keys)):
			Parameter.PLAYER_NAMES[i]=MultiplayerConnectHandler.player_names[keys[i]].alias;
			item.set_player_id(i);
			item.visible=true;
		else:
			item.visible=false;

func start_session_timer(force:bool=false):
	session_timer.start(force);

func pause_session_timer():
	session_timer.pause();

func stop_session_timer():
	session_timer.stop();
	
func _on_timer_finish():
	_reset_lobby_state(true);
	
func _on_all_peers_connected():
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn");

func _on_receive_network_update(key, msg):
	var ebind=null;
	if (key in ["CONNECT_FAILED", "CONTACT_FAILED"]):
		if (option_id==2):
			msg="T_ATTEMPT_FAILED_RETRY_EPS";
		_reset_lobby_state(false);
	elif (key in ["CONNECT_SUCCESS", "CONTACT_SUCCESS"]):
		msg="T_CONNECTING_TO_SERVER_EPS";
	elif (key in ["SESSION_REGISTERED"]):
		var game_code=str(MultiplayerConnectHandler.game_code);
		ebind=game_code;
		if (option_id==0):
			msg="T_SHARE_GAME_CODE_CLN_ENUM";
		elif (option_id==1):
			msg="T_CHECKING_GAME_CODE_ENUM";
		elif (option_id==2):
			msg="T_WAITING_FOR_OTHER_PLAYERS_EPS";
			
	if (!session_timer.is_running()): # no need to update anything further
		pass;
	if (key in ["PEER_CONNECTED"]):
		pause_session_timer();
		notice_label.set_enumeration_bind("--");
		notice_label.set_translate_key(0, "T_SESSION_EXPIRES_IN_ENUM_SECONDS");
	if (ebind!=null):
		status_label.set_enumeration_bind(ebind);
	status_label.set_translate_key(0, msg);

func _on_previous_button_pressed():
	# go to previous item
	if (changing_state):
		return;
	changing_state=true;
	option_id=max(0,option_id-1);
	_reset_lobby_state(true);
	changing_state=false;

func _on_next_button_pressed():
	# go to next item
	if (changing_state):
		return;
	changing_state=true;
	option_id=min(len(option_translate_keys), option_id+1);
	_reset_lobby_state(true);
	changing_state=false;
	
func _on_options_button_pressed():
	# what happens when you click the bottom button
	if (changing_state || player_name==null || len(player_name)==0):
		return;
	if (session_active): # button.current_text=cancel
		_reset_lobby_state();
	else:
		Parameter.PANEL_ACTIVE=true;
		Events.emit_signal("show_panel_lobby_popup", option_id);

func _reset_lobby_state(reset_status:bool=true):
	stop_session_timer();
	if (MultiplayerConnectHandler.exit_lobby || MultiplayerConnectHandler.network_locked):
		return;
	if (reset_status):
		status_label.set_translate_key(0, default_status_translate_key);
	self.session_active=false;
	MultiplayerConnectHandler.reset_networking();
	MultiplayerConnectHandler.reset_state();
	notice_label.set_translate_key(0, option_messages[option_id]);
	_set_option_button_text(option_translate_keys[option_id]);
	Events.emit_signal("show_panel_lobby_popup", -1); # make popups invisible

func _process(_delta):
	# name setup
	if (self.player_name!=MultiplayerConnectHandler.selfname):
		self.player_name=MultiplayerConnectHandler.selfname;
	
	# if id changed
	var max_id=len(option_translate_keys)-1;
	previous_button.visible=(option_id!=0) && !session_active;
	next_button.visible=(option_id!=max_id) && !session_active;
	
	if (session_active):
		if (session_timer.is_running()):
			var time_remaining=session_timer.get_remaining_time();
			var remaining_session_time=int(time_remaining);
			notice_label.set_enumeration_bind("%02d"%[remaining_session_time]);
			notice_label.set_translate_key(0, "T_SESSION_EXPIRES_IN_ENUM_SECONDS");
	else:
		notice_label.set_translate_key(0, option_messages[option_id]);
	
	_update_player_list();
	if (MultiplayerConnectHandler.exit_lobby):
		stop_session_timer();
