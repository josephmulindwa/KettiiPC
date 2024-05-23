extends Node

var player_names={}; # map of (name, id)
var _player_ids=[];
var selfname="";

var hole_puncher;
var exit_lobby:bool=false;
var network_locked:bool=false;
var reconnecting:bool=false;
var peer_data={};
var game_code;
const traversal_server_ip:="66.135.5.170"; #66.135.5.170
const traversal_server_port=13000;
const GAME_PORT=4545;
const GAME_CODE_SIZE=4;
var is_host=false;
var peer_id;
var own_port;
var host_port;
var host_address;
var p_timer;
var on_peers_connected_callback=null;

var status_keys:Array=[]; # string status keys from holepuncher.status
signal update_status(key, msg);

func _ready():
	# timer logic
	_set_network_signals();
	
	
func _set_network_signals():
	self.multiplayer.connected_to_server.connect(
		func():
			await get_tree().create_timer(1).timeout;
			# send self stats to server
			submit_player_name.rpc_id(1, selfname, self.multiplayer.multiplayer_peer.get_unique_id(), own_port);
	)

	# Emitted when a connection attempt succeeds.
	self.multiplayer.connection_failed.connect(
		func():
			await get_tree().create_timer(1).timeout;
			emit_signal("update_status", "CONNECT_FAILED", "T_FAILED_TO_CONNECT");
	)

	# Emitted by the server when a client connects.
	self.multiplayer.peer_connected.connect(
		func(id):
			await get_tree().create_timer(1).timeout;
			add_player_id(id);
	);
	
	# Emitted by the server when a client disconnects.
	self.multiplayer.peer_disconnected.connect(
		func(_id):
			await get_tree().create_timer(1).timeout;
			emit_signal("update_status", "PEER_DISCONNECTED", "T_OTHER_PLAYER_DISCONNECTED");
	);

	# Emitted by clients when the server disconnects.
	self.multiplayer.server_disconnected.connect(
		func():
			await get_tree().create_timer(1).timeout;
			emit_signal("update_status", "PEER_DISCONNECTED", "T_OTHER_PLAYER_DISCONNECTED");
	);

func _update_network_status(status):
	# broadcasts textual status
	var defn={
		"CONNECT_FAILED":"T_FAILED_TO_CONNECT",
		"CONNECT_SUCCESS":"T_CONNECTED",
		"CONTACT_FAILED":"T_FAILED_TO_CONNECT",
		"GREET_STARTED":"T_WAITING_FOR_OTHER_PLAYERS_EPS",
		"CONTACT_SUCCESS":"T_CONNECTED_TO_SERVER",
		"CONFIRM_STARTED":"T_WAITING_FOR_OTHER_PLAYERS_EPS",
		"GO_STARTED":"T_WAITING_FOR_OTHER_PLAYERS_EPS",
		"CONNECT_STARTED":"T_CONNECTED_TO_SERVER",
		"PEER_CONNECTED":"T_WAITING_FOR_OTHER_PLAYERS_EPS",
		"SESSION_REGISTERED":"T_WAITING_FOR_OTHER_PLAYERS_EPS",
		"PEER_DISCONNECTED":"T_OTHER_PLAYER_DISCONNECTED"
	};
	var str_status=status_keys[status];
	if (str_status in defn.keys()):
		emit_signal('update_status', str_status, defn[str_status]);

func _update_lock_status(stage):
	if (hole_puncher==null):
		network_locked=false;
		return;
	if (network_locked): # network should be unlocked externally
		return;
	if (stage==hole_puncher.PEER_GO || stage==hole_puncher.PEER_CONFIRM):
		network_locked=true;

func add_player_id(id):
	if (id not in _player_ids):
		_player_ids.append(id);
	on_submit_completed();

func _reset_params(reset_name:bool=true):
	self.player_names={};
	self._player_ids=[];
	self.exit_lobby=false;
	self.hole_puncher=null;
	self.network_locked=false;
	self.reconnecting=false;
	self.peer_data={};
	if (reset_name):
		self.selfname="";
	
func reset_state():
	_reset_params(false);

func setup_server_for_local_game():
	reset_state();
	var peer=ENetMultiplayerPeer.new();
	peer.create_server(GAME_PORT, 2);
	self.multiplayer.multiplayer_peer=peer;
	# get_tree().set_multiplayer(peer);
	# setup world here
	peer_id=self.multiplayer.get_unique_id();
	get_node('/root').set_multiplayer_authority(peer_id, true);
	self.exit_lobby=true;
	
func connect_to_server(code):
	self.game_code=code;
	reset_state();
	self.is_host=false;
	var result = await traverse_nat(false);
	if (!result):
		return;
	host_address=result[2];
	host_port=result[1];
	own_port=result[0];
	await get_tree().create_timer(2.0).timeout
	await _start_client_logic();
	
func start_server(is_random:bool=false):
	# starts up server logic
	self.game_code=generate_game_code();
	reset_state();
	self.is_host=true;
	var result=await traverse_nat(true, is_random);
	if (!result):
		return;
	own_port=result[0];
	await _start_server_logic();

func start_random():
	self.game_code=generate_game_code();
	GameDataManager.SAVEDATA.number_players=2;
	reset_state();
	self.is_host=true;
	var result=await traverse_nat(true, true);
	if (!result):
		return;
	if (result[0]==-1): # rc
		var string_parts=result[2].split(':');
		var started_session=false;
		if (len(string_parts)==2):
			var connection_type=string_parts[0];
			var code=string_parts[1];
			if (connection_type!=null && connection_type==hole_puncher.REGISTER_CLIENT.left(2)):
				reset_networking();
				started_session=true;
				await connect_to_server(code);
		if (!started_session):
			_update_network_status("Failed to connect"); # like failed to connect to server
			reset_networking();
	else: # server started
		own_port=result[0];
		await _start_server_logic();

func _start_server_logic():
	var peer=ENetMultiplayerPeer.new();
	var err=peer.create_server(own_port, GameDataManager.SAVEDATA.number_players-1);
	if (err!=OK):
		_update_network_status(hole_puncher.STATUS.CONNECT_FAILED);
		return false;
	else:
		_update_network_status(hole_puncher.STATUS.CONNECT_SUCCESS);
	self.multiplayer.multiplayer_peer=peer;
	peer_id=self.multiplayer.get_unique_id();
	# signals
	add_player_id(peer_id);
	add_name(selfname, peer_id, own_port);
	return true;

func _start_client_logic():
	var peer=ENetMultiplayerPeer.new();
	var err=peer.create_client(host_address, host_port, 0, 0, 0, own_port);
	if(err!=OK):
		_update_network_status(hole_puncher.STATUS.CONNECT_FAILED);
		return false;
	else:
		_update_network_status(hole_puncher.STATUS.CONNECT_SUCCESS);
	self.multiplayer.multiplayer_peer=peer;
	peer_id=self.multiplayer.get_unique_id();
	return true;

func reset_networking():
	if (hole_puncher!=null):
		if (hole_puncher.is_host):
			hole_puncher.finalize_peers(game_code);
		# we shouldn't have to call this as the server normally
		# does this when we call finalize_peers,
		# but if our client is still registered in an old, lingering session
		# it won't get cleaned up without the following call
		hole_puncher.checkout();
		hole_puncher.queue_free();
	
	if (self.multiplayer.multiplayer_peer==null):
		return;
	self.multiplayer.multiplayer_peer.close();
	self.multiplayer.multiplayer_peer=null;

func on_submit_completed():
	# update for all peers
	update_peer_data.rpc(player_names); # tell clients to update their list
	if (self.is_host && 
		len(player_names)>=GameDataManager.SAVEDATA.number_players &&
		len(_player_ids)>=GameDataManager.SAVEDATA.number_players
	):
		self.stop_receiving_peers();
		stop_receiving_peers.rpc();
		# load game scene
		on_exit_lobby.rpc();
		self.on_exit_lobby();

@rpc("authority", "call_remote", "reliable")
func stop_receiving_peers():
	self.multiplayer.refuse_new_connections=true;

func add_name(_name, id, port):
	"""
	adds name to key with duplicates in mind
	peers are identified by their ports - not ids
	"""
	_name=_name.to_upper();
	var key=_name+"-"+str(port);
	var alias=_name # the name that will be saved & shown
	var name_counts=0;
	for ky in player_names.keys():
		var parts=ky.split("-");
		if (parts[0]==_name):
			name_counts+=1
	if (name_counts>0):
		alias=alias+"(%s)"%(name_counts);
	player_names[key]={"alias":alias, "id":id};

@rpc("any_peer", "call_remote", "reliable")
func submit_player_name(_name, id, port):
	# submits this name to server with id
	add_name(_name, id, port);
	if (!exit_lobby):
		on_submit_completed();
	
@rpc("any_peer", "call_remote", "reliable")
func update_peer_data(data):
	# send server peer list to clients
	if (is_host): # to be rejected by host
		return;
	self.player_names=data;

@rpc("authority", "call_remote", "reliable")		
func on_exit_lobby():
	# loads new scene
	self.exit_lobby=true; # for rpc update
	GameDataManager.SAVEDATA.number_players=len(player_names);
	network_locked=false;
	if (on_peers_connected_callback!=null):
		on_peers_connected_callback.call();

func traverse_nat(_is_host, is_random=false):
	hole_puncher=preload('res://addons/Holepunch/holepunch_node.gd').new();
	hole_puncher.rendevouz_address=traversal_server_ip;
	hole_puncher.rendevouz_port=traversal_server_port;
	add_child(hole_puncher);
	status_keys=hole_puncher.STATUS.keys();
	hole_puncher.session_registered.connect(_session_registered);
	hole_puncher.broadcast_status.connect(_update_network_status);
	var player_host='host' if (_is_host) else 'client';
	var rankey=str(randi_range(1, 5000));
	var traversal_id='{'+selfname.sha1_text()+"-"+rankey+'}'+"_"+str(player_host); # id here
	var success=await hole_puncher.start_traversal(game_code, _is_host, traversal_id, is_random);
	if (!success):
		return;
	if (hole_puncher!=null):
		var result=await hole_puncher.hole_punched;
		peer_data=hole_puncher.peers;
		await get_tree().create_timer(0.1).timeout;
		return result;

func generate_game_code():
	# use a local randomized RNG to kep the global RNG reproducible
	var rng=RandomNumberGenerator.new();
	rng.randomize();
	var length=4;
	var result='';
	for _n in range(length):
		var ascii=rng.randi_range(0, 25)+65;
		result+='%c'%ascii;
	return result;
	
func _session_registered():
	emit_signal('update_status', "SESSION_REGISTERED", "T_WAITING_FOR_OTHER_PLAYERS_EPS",);
	
# remove ourselves from the holepunch server before exiting
func _notification(what):
	if((what==NOTIFICATION_WM_CLOSE_REQUEST || what==NOTIFICATION_WM_GO_BACK_REQUEST) && (hole_puncher!=null && is_instance_valid(hole_puncher))):
		hole_puncher.checkout();
		if (hole_puncher.is_host):
			hole_puncher.finalize_peers(game_code);
