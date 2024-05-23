extends GameManagerCore;

var connected_peer_ids:Array=[];
var ready_players:Array=[];
var ready_states={};
var prev_state_broadcast=[];

var peer_sense_timer;
var peer_sense_max_retries=15; 
var peer_sense_retries=0;

func _set_network_signals():
	self.multiplayer.connected_to_server.connect(
		func():
			await get_tree().create_timer(1).timeout;
	);

	# Emitted when a connection attempt succeeds.
	self.multiplayer.connection_failed.connect(
		func():
			await get_tree().create_timer(1).timeout;
	);

	# Emitted by the server when a client connects.
	self.multiplayer.peer_connected.connect(
		func(id):
			await get_tree().create_timer(1).timeout;
			if (id not in self.connected_peer_ids):
				self.connected_peer_ids.append(id);
	);
	
	# Emitted by the server when a client disconnects.
	self.multiplayer.peer_disconnected.connect(
		func(id):
			await get_tree().create_timer(1).timeout;
			# MCH.reconnect_to_peers
			
			# setup to show offline icon
			for ky in MultiplayerConnectHandler.player_names.keys():
				var kvalue=MultiplayerConnectHandler.player_names[ky];
				if (kvalue.id==id):
					var idx=Parameter.PLAYER_NAMES.find(kvalue.alias);
					if (idx!=-1):
						Parameter.PLAYER_CONNECTION_STATES[idx]=Parameter.CONNECTION_STATE.DISCONNECTED;
					break;
	);

	# Emitted by clients when the server disconnects.
	self.multiplayer.server_disconnected.connect(
		func():
			await get_tree().create_timer(1).timeout;
	);

# Called when the node enters the scene tree for the first time.
func _ready():
	# set up network signals
	super();
	Parameter.GAME_READY=false;
	
	_set_network_signals();
	self.multiplayer.multiplayer_peer=MultiplayerConnectHandler.multiplayer.multiplayer_peer;
	self.connected_peer_ids.append(MultiplayerConnectHandler.peer_id);
	ready_players.append(MultiplayerConnectHandler.peer_id);
	
	peer_sense_timer=Timer.new();
	add_child(peer_sense_timer);
	peer_sense_timer.name="PeerSenseTimer";
	peer_sense_timer.timeout.connect(_sense_peers);
	peer_sense_timer.wait_time=1.0;
	peer_sense_timer.start();

	Parameter.CYCLE_TIMER_OBJECT.set_elapse(15.0);
	Parameter.CYCLE_TIMER_OBJECT.set_elapse_callback(_handle_perform_nextplayer_countdown);

	apply_load_state();
	if (MultiplayerConnectHandler.peer_id==1):
		Parameter.STATE_HANDLER.set_state("START_CYCLE");

func _sense_peers():
	var _peers=self.multiplayer.get_peers();
	var is_ready=(len(ready_players)==GameDataManager.SAVEDATA.number_players);
	# broadcast
	GameUtils.call_rpc_on_peers(broadcast_ready_state, [MultiplayerConnectHandler.peer_id, ready]);
	peer_sense_retries+=1;
	if (is_ready):
		ready_states[MultiplayerConnectHandler.peer_id]=true;
	if (peer_sense_retries>=peer_sense_max_retries):
		peer_sense_timer.stop();
		peer_sense_timer.queue_free();
		if (len(_peers)==0 || len(ready_states)==0): # || !GAME_READY
			_disconnected_end_game_procedure();
		return;
	# all players are ready
	if (len(ready_states)==GameDataManager.SAVEDATA.number_players):
		Parameter.GAME_READY=true;
		_peers.append(MultiplayerConnectHandler.peer_id);
		return;

func _disconnected_end_game_procedure():
	# used to end game when players are disconnected
	GameDataManager.SAVEDATA.number_players=1;
	Parameter.GAME_COMPLETED=true;
	Events.emit_signal("show_panel_game_over");
	Parameter.GAME_PAUSED=true;
	
func broadcast_location(sound_name=null):
	if(Parameter.CURRENT_PLAYER_ID!=Parameter.SELF_PLAYER_ID):
		return;
	GameUtils.call_rpc_on_peers(update_location, [GameDataManager.SAVEDATA.active_player_index, self.player_locations, sound_name]);

func broadcast_game_state():
	# current player broadcasts state
	if(Parameter.CURRENT_PLAYER_ID!=Parameter.SELF_PLAYER_ID):
		return;
	var curr_state_broadcast=[GameDataManager.SAVEDATA.active_player_index, Parameter.STATE];
	GameUtils.call_rpc_on_peers(_broadcast_game_state, curr_state_broadcast);

func is_running_nextplayer_timer():
	return Parameter.CYCLE_TIMER_OBJECT.is_running();

func start_nextplayer_timer():
	Parameter.CYCLE_TIMER_OBJECT.start();
	
func stop_nextplayer_timer():
	Parameter.CYCLE_TIMER_OBJECT.stop();

func _handle_perform_nextplayer_countdown():
	#Parameter.END_CYCLE=true;
	force_non_waiting_move_to_next(); # call on self
	broadcast_game_state(); # tell peers to start cycle

func update_rpc_counter(event:bool=false):
	"""
	updates rpc counter used to determine which rpc is recent;
	a counter is {cycle_count}.{current_player}+{event_eps}
	@params
	event:bool, default=false
		adds a small value to the current cycle.
	"""
	if (Parameter.CURRENT_PLAYER_ID!=Parameter.SELF_PLAYER_ID):
		return;
	if (event):
		GameUtils.rpc_cycle_counter+=0.000001;
	else:
		var cycle=int(GameUtils.rpc_cycle_counter);
		cycle+=1.0;
		cycle=float(cycle)+(GameDataManager.SAVEDATA.active_player_index/float(Parameter.MAX_PLAYERS));
		GameUtils.rpc_cycle_counter=cycle;

func force_non_waiting_move_to_next():
	await super();
	broadcast_game_state();

func render_piece_locations(loc_matrix:Array):
	# renders pieces to location in loc_matrix
	for i in range(GameDataManager.SAVEDATA.number_players):
		var id:int=GameDataManager.SAVEDATA.player_mapping[i];
		for j in range(Parameter.MAX_PIECES):
			move_location(id, j, loc_matrix[id][j]);

func on_start_cycle():
	# sets up for a fresh cycle by clearing ALL states
	await super();
	Parameter.CYCLE_TIMER_OBJECT.stop();
	update_rpc_counter();
	broadcast_game_state();
	
func check_rpc_counter_validity(rpcc):
	if (rpcc<GameUtils.rpc_cycle_counter): # if sender rpcc is old, decline & tell them to update
		sync_rpc_counter.rpc_id(self.multiplayer.get_remote_sender_id(), GameUtils.rpc_cycle_counter);
		return false;
	return true;

@rpc("any_peer", "call_remote", "reliable")
func sync_rpc_counter(value):
	GameUtils.rpc_cycle_counter=value;

func on_await_piece_select(movable_states:Array):
	# sets up procedure for awaiting piece
	Parameter.STATE_HANDLER.append_state("AWAIT_PIECE_SELECT");
	Parameter.STATE.MOVING_PIECE_ID=-1;
	Parameter.STATE.MOVING_PLAYER_ID=-1;
	if (Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.HUMAN):
		# set markers
		for i in range(Parameter.MAX_PIECES):
			var is_movable = movable_states[i];
			if (is_movable):
				self.player_pieces[Parameter.CURRENT_PLAYER_ID][i].add_marker();
			else:
				self.player_pieces[Parameter.CURRENT_PLAYER_ID][i].remove_marker();

var prev=[];
@rpc("any_peer", "call_remote", "unreliable", 1)
func _broadcast_game_state(player_index:int, parameter_state, rpcc=GameUtils.rpc_cycle_counter):
	"""
	calls from active peer to send self stats to peers
	"""
	if([player_index, parameter_state]!=prev):
		prev=[player_index, parameter_state];
		
	if (!check_rpc_counter_validity(rpcc)):
		return;
	GameUtils.rpc_cycle_counter=rpcc;
	GameDataManager.SAVEDATA.active_player_index=player_index;
	Parameter.CURRENT_PLAYER_ID=GameDataManager.SAVEDATA.player_mapping[player_index];
	Parameter.STATE=parameter_state;
	Parameter.STATE_HANDLER.change_state_int(Parameter.STATE.STATE);

@rpc("any_peer", "call_remote", "unreliable", 1)
func broadcast_ready_state(self_id, is_ready, _rpcc=0):
	"""
	used to notify peers that game is ready to start
	caller sends its id to be registered by peers
	along with a ready state
	"""
	if (self_id not in ready_players):
		ready_players.append(self_id);
	if (is_ready):
		ready_states[self_id]=true;

@rpc("any_peer", "call_remote", "unreliable", 2)
func update_location(active_player_index:int, loc_matrix:Array, sound_name=null, rpcc=0.0):
	# updates state in peer it is called on
	if (!check_rpc_counter_validity(rpcc)):
		return;
	GameUtils.rpc_cycle_counter=rpcc;
	GameDataManager.SAVEDATA.active_player_index=active_player_index;
	if (sound_name!=null):
		Events.emit_signal("play_sound", sound_name);
	if (self.player_locations!=loc_matrix):
		Parameter.CURRENT_PLAYER_ID=GameDataManager.SAVEDATA.player_mapping[active_player_index];
		render_piece_locations(loc_matrix); # call before update else won't move
		self.player_locations=loc_matrix;
		GameDataManager.SAVEDATA.location_matrix=loc_matrix;
		# update percentages;
		Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.CURRENT_PLAYER_ID]=get_player_completion_percentage(Parameter.CURRENT_PLAYER_ID);

func update_external_states():
	broadcast_game_state();

func _process(delta):
	super(delta);
	
	# if 1 player is left; exit
	var remaining_players=0;
	for i in range(GameDataManager.SAVEDATA.number_players):
		var _id=GameDataManager.SAVEDATA.player_mapping[i];
		if (Parameter.PLAYER_CONNECTION_STATES[_id]!=Parameter.CONNECTION_STATE.DISCONNECTED):
			remaining_players+=1;
		else:
			Parameter.PLAYER_COMPLETION_STATES[_id]=true; # fix
	if (remaining_players<=1):
		Parameter.GAME_PAUSED=true;
		_disconnected_end_game_procedure();
		
	
	if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_ROLL")):
		if (!is_running_nextplayer_timer()):
			start_nextplayer_timer();
		broadcast_game_state();
	
	if (Parameter.STATE_HANDLER.check_if_state_is("ROLLED")): # Parameter.SELF_PLAYER_ID has rolled
		update_rpc_counter();
		broadcast_game_state();
		if (Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID):
			# get movable state of all rolls
			var mark_roll=Parameter.ROLLS[0];
			var all_rolls_same=true;
			for i in range(Parameter.MAX_DIE):
				var _roll=Parameter.ROLLS[i];
				all_rolls_same = all_rolls_same && (_roll==mark_roll);
			self.same_rolls=all_rolls_same;
			self.roll_movable_counts=get_roll_movable_counts();
			self.previous_pad_id=-1; # added
			for i in range(len(self.roll_movable_counts)):
				if (self.roll_movable_counts[i]>0):
					self.can_move=true;
					Parameter.STATE.SELECTED_PAD_ID=i; # enable to mark pad_id
					break;
			if(self.can_move):
				Parameter.STATE_HANDLER.set_state("AWAIT_PAD_SELECT");
			else:
				Parameter.STATE_HANDLER.set_state("END_CYCLE");
		self.previous_pad_id=-1;
		Parameter.STATE_HANDLER.disable_state("ROLLED");
		broadcast_game_state();
	
	if(Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PAD_SELECT")):
		if (!is_running_nextplayer_timer()):
			start_nextplayer_timer();
		broadcast_game_state();
		# filter used rolls & pad_cannot_move
		if(Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID):
			# allow to pick non-movable pads after-all, they wont be movable
			if(Parameter.STATE.SELECTED_PAD_ID!=previous_pad_id):
				var _roll = Parameter.ROLLS[Parameter.STATE.SELECTED_PAD_ID];
				var movable_states:Array = get_movable_states(_roll);
				on_await_piece_select(movable_states);
				previous_pad_id=Parameter.STATE.SELECTED_PAD_ID;
		else:
			Parameter.STATE_HANDLER.append_state("AWAIT_PIECE_SELECT");
		broadcast_game_state();
	
	if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PIECE_SELECT")):
		broadcast_game_state();
		if (Parameter.STATE.MOVING_PIECE_ID!=-1 && Parameter.STATE.MOVING_PLAYER_ID!=-1):
			# set up for moving
			if (self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID]==Parameter.YARD_LOCATION):
				# out of base
				self.move_type=MOVE_TYPE.YARD;
				self.moves=1;
			else:
				self.moves=Parameter.ROLLS[Parameter.STATE.SELECTED_PAD_ID];
				self.target_location_steps=self.moves;
			start_moving(self.moves);
		broadcast_game_state();
	
	if (Parameter.STATE_HANDLER.check_if_state_is("MOVING")):
		if(is_running_nextplayer_timer()):
			stop_nextplayer_timer();
		if (Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID):
			update_rpc_counter(true);
			broadcast_game_state(); # this line was 1 line above
			var move_steps = int(move_step_elapse/GameDataManager.CONFIGDATA.game_speed);
			if (move_steps):
				var moving_piece = self.player_pieces[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
				var remaining_steps = target_location_steps-moving_location_steps;
				if (moving_location_steps<target_location_steps):
					forward_pass=true;
					if(move_steps>remaining_steps):
						move_steps=remaining_steps;
					Events.emit_signal("play_sound", "PIECE_MOVE");
					move_player_piece(moving_piece, move_steps);
					moving_location_steps+=move_steps;
					broadcast_location("PIECE_MOVE");
				elif (moving_location_steps>target_location_steps):
					forward_pass=false;
					remaining_steps*=-1;
					if(move_steps>remaining_steps):
						move_steps=remaining_steps;
					move_player_piece(moving_piece, -move_steps);
					moving_location_steps-=move_steps;
					broadcast_location();
			
			
			if (moving_location_steps==target_location_steps):
				var location = self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
				var last_tile:Tile = location_to_tile(location, Parameter.STATE.MOVING_PLAYER_ID, Parameter.STATE.MOVING_PIECE_ID);
				# check if *just reached home
				if(Parameter.STATE.MOVING_PLAYER_ID==Parameter.CURRENT_PLAYER_ID):
					if(location==Parameter.HOME_LOCATION):
						move_type=MOVE_TYPE.HOME;
						Events.emit_signal("play_sound", "REACHED_HOME");
						broadcast_location("REACHED_HOME");
				# check collisions
				var found_collider=false;
				if(!Parameter.LOCK_COLLISION):
					var this_piece=self.player_pieces[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
					var colliding_piece=last_tile.get_colliding_piece(this_piece, forward_pass);
					if (colliding_piece!=null):
						if (!piece_in_safe_zone(colliding_piece)): # move backwards
							found_collider=true;
							colliding_piece.start_explosion_effect();
							self.move_type=MOVE_TYPE.ATTACK;
							Events.emit_signal("play_sound", "PIECE_EXPLODE");
							broadcast_location("PIECE_EXPLODE");
							Parameter.STATE.MOVING_PLAYER_ID=colliding_piece.player_id;
							Parameter.STATE.MOVING_PIECE_ID=colliding_piece.piece_id;
							var curr_location=self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
							var new_location=get_backward_location(curr_location);
							start_moving(new_location-curr_location);
							# set up speed for moving backwards && reset speed later
							GameDataManager.CONFIGDATA.set_game_speed(0.01, false);
				if (!found_collider):
					GameDataManager.CONFIGDATA.reset_game_speed();
					Parameter.STATE.ROLLS_USED[Parameter.STATE.SELECTED_PAD_ID]=true;
					Parameter.STATE_HANDLER.set_state("END_CYCLE");
					update_rpc_counter();
					broadcast_game_state();
				Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.STATE.MOVING_PLAYER_ID] = get_player_completion_percentage(Parameter.STATE.MOVING_PLAYER_ID);
			# set to remainder
			move_step_elapse=move_step_elapse-(move_steps*GameDataManager.CONFIGDATA.game_speed);
			move_step_elapse+=delta;
		
	if(Parameter.STATE_HANDLER.check_if_state_is("END_CYCLE")):
		broadcast_game_state();
		if (cycle_pause_elapse>=cycle_pause_delay):
			# broadcast location
			if (Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID):
				broadcast_location();
			else:
				return;
			var move_to_next=true;
			if (self.can_move && Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.CURRENT_PLAYER_ID]!=100):
				self.roll_movable_counts = get_roll_movable_counts(); # update
				for i in range(Parameter.MAX_DIE):
					if(!Parameter.STATE.ROLLS_USED[i] && self.roll_movable_counts[i]>0):
						Parameter.STATE.SELECTED_PAD_ID=i;
						move_to_next=false;
						Parameter.STATE_HANDLER.set_state("AWAIT_PAD_SELECT");
						broadcast_game_state();
						break;
			if (move_to_next):
				if (!move_type==MOVE_TYPE.ATTACK && !move_type==MOVE_TYPE.YARD && !move_type==MOVE_TYPE.HOME && !self.same_rolls):
					go_to_next_player_index();
				Parameter.STATE_HANDLER.set_state("START_CYCLE");
			Parameter.STATE_HANDLER.disable_state("END_CYCLE");
			cycle_pause_elapse=0.0;
			broadcast_game_state();
		cycle_pause_elapse+=delta;
