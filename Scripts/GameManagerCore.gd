extends Node

class_name GameManagerCore;

"""Logic to handle game scene"""

enum MOVE_TYPE {ATTACK=6, EVADE=5, YARD=4, HOME=3, CASCADE=2, FORWARD=1, NONE=0};
enum ROLL_TYPE {ZERO=0, ONE=1, ALL=2, NONE=-1};

var last_pause_time=null;
var end_game_popup_shown:bool=false;
var forward_pass=true; # the forward motion pass state
var move_step_elapse:float;
var cycle_pause_elapse=0.0; var cycle_pause_delay:float=0.9;
var moves:int;
var same_rolls:bool;
var can_move:bool;
var swapping_piece:bool=false;
var tiles_flipped:bool=false;
var previous_pad_id:int; # used to ensure non-wasteful cpu when pad is same
var division_angle:float = 360.0/Parameter.MAX_DIVISIONS;
var home_collision_tiles:Array[Array]=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS,Parameter.MAX_PIECES);
var yard_collision_tiles:Array[Array]=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS,Parameter.MAX_PIECES);
var sector_collision_tiles:Array=CoreUtils.create_array_1d(Parameter.MAX_SECTORS*Parameter.MAX_DIVISIONS);
var player_pieces:Array=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS,Parameter.MAX_PIECES,null); 
var entrance_tiles:Array=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS);
var tile_data:Array; # tile data for sorting [(x, y), obj]
var location_offsets=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS);
var player_locations:Array;
var player_completion_listing=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, -1);
var player_completion_index:int=0;
var roll_movable_counts:Array; # counts of movable pieces by current rolls
var moving_location_steps:int=0; var target_location_steps:int=0;
var moved:bool=false;
var explosion_object=null;

var safe_location_templates:Array[int] = [1,9,11,19,21,29,31,39,40]; # of zero-indexed location; of individual player
var safe_locations:Array;

var move_type:MOVE_TYPE;
var roll_pick_type:ROLL_TYPE;

func _ready():
	get_tree().set_quit_on_go_back(false);
	Parameter.GAME_READY=false;
	
	# update percentages from location data, and types
	self.player_locations=GameDataManager.SAVEDATA.location_matrix;
	for m in range(Parameter.MAX_PLAYERS):
		Parameter.PLAYER_COMPLETION_PERCENTAGES[m]=get_player_completion_percentage(m);
	
	# preload prefabs
	var tile_prefabs:Array=[
		GameDataManager.ASSETS["sector_tile_i"],
		GameDataManager.ASSETS["sector_tile_ii"],
		GameDataManager.ASSETS["sector_tile_iii"],
		GameDataManager.ASSETS["sector_tile_iv"],
	];
	
	# fill homes
	var home_names:Array[String] = ["Home_Red", "Home_Blue", "Home_Yellow", "Home_Green"];
	var homes_parent=$HomesParent;
	for i in range(len(home_names)):
		var home_tiles_parent = homes_parent.get_node(home_names[i]);
		for j in range(Parameter.MAX_PIECES):
			home_collision_tiles[i][j] = home_tiles_parent.get_child(j);
			home_collision_tiles[i][j].name=home_names[i]+"_"+str(j);

	# fill yards
	var yard_names:Array[String] = ["Yard_Red", "Yard_Blue", "Yard_Yellow", "Yard_Green"];
	var yards_parent=$YardsParent;
	for i in range(len(yard_names)):
		var yard_tiles_parent=yards_parent.get_node(yard_names[i]);
		for j in range(Parameter.MAX_PIECES):
			yard_collision_tiles[i][j] = yard_tiles_parent.get_child(j);
			yard_collision_tiles[i][j].name=yard_names[i]+"_"+str(j);
	
	# set locationOffsets
	for i in range(len(location_offsets)):
		var _t=float(Parameter.MAX_DIVISIONS)/float(Parameter.MAX_PLAYERS);
		location_offsets[i] = int(_t)*i;
	
	#fill safe locations
	var k=0;
	safe_locations=CoreUtils.create_array_1d(Parameter.MAX_SECTORS*len(safe_location_templates));
	for i in range(Parameter.MAX_SECTORS):
		for j in range(len(safe_location_templates)):
			safe_locations[k] = safe_location_templates[j]+(i*Parameter.MAX_DIVISIONS);
			k+=1;
	
	# setting tiles and entrances
	var n=0;
	var l=0;
	var sector_tiles_parent=$SectorTilesParent;
	for i in range(Parameter.MAX_SECTORS+1):
		var tile_prefab = tile_prefabs[i];
		for j in range(Parameter.MAX_DIVISIONS):
			if(i>=Parameter.MAX_SECTORS): # if entrance sector 
				if(j==0 || j%10!=Parameter.BOARD_SHIFT-1): # ...and not entrance
					continue;
			var angle = division_angle*j;
			var tile=tile_prefab.instantiate();
			# temporarily add to get stats and then remove; to be re-added after sort
			sector_tiles_parent.add_child(tile);
			tile.name="Tile_"+str(i)+"_"+str(j);
			tile.rotation_degrees=angle;
			tile.sector=i;
			tile_data.append([tile.inner.global_position, tile]);
			sector_tiles_parent.remove_child(tile);
			# add to lists
			if(i<Parameter.MAX_SECTORS):
				sector_collision_tiles[n]=tile;
				n+=1;
			else:
				entrance_tiles[l]=tile;
				l+=1;
	
	# sort tiles so that top most appear first; pieces on them won't overlap weirdly
	tile_data.sort_custom(func(a, b): return CoreUtils.sort_for_miny_maxx(a[0], b[0]));
	set_board_flip(false);
	setup_tile_orientation(false, true); # force dont flip tile orientation
	if (GameDataManager.SAVEDATA.active_game_mode in [Parameter.GAME_MODE.CPU, Parameter.GAME_MODE.ONLINE]):
		if (Parameter.SELF_PLAYER_ID>=(Parameter.MAX_PLAYERS/2.0)):
			set_board_flip(true);
			setup_tile_orientation(false, true);
	
	self.tree_exiting.connect(
		func():
			GameUtils.free_items(CoreUtils.array_ravel_2d(player_pieces));
			GameUtils.free_items(sector_collision_tiles);
	);
	
	# placing pieces
	add_pieces_to_scene();
	if (GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.ONLINE):
		Parameter.STATE_HANDLER.set_state("START_CYCLE");
	
	return;

func set_board_flip(flipped):
	"""flips the entire board"""
	if (flipped):
		self.rotation_degrees=180.0;
	else:
		self.rotation_degrees=0.0;

func setup_tile_orientation(flip, force:bool=false):
	"""
	places tiles in a flipped or non-flipped order
	flipped : whether to flip the tile orientation or not
	force   : whether to reinforce the orientation even if its already set
	"""
	var _already_flipped=(flip==tiles_flipped);
	if (!force && _already_flipped):
		return;
	
	var indices=[];
	if (!flip):
		for i in range(len(tile_data)):
			indices.append(i);
	else:
		for i in range(len(tile_data)-1, -1, -1):
			indices.append(i);
	
	var sector_tiles_parent=$SectorTilesParent;
	for i in indices:
		var pair=tile_data[i];
		var tile=pair[1];
		if (tile.get_parent()==sector_tiles_parent):
			sector_tiles_parent.remove_child(tile);
		sector_tiles_parent.add_child(tile);
		#sector_tiles_parent.move_child(tile, i);
	tiles_flipped=flip;

func add_pieces_to_scene():
	"""
	places pieces of appropriate type onto the scene
	immediately attaches them to an appropriate location tile
	"""
	
	var target_width=Parameter.STANDARD_TILE_SIZE;
	var piece_prefabs=Parameter.RIM_PIECE_PREFABS;
	Parameter.PIECE_SIZE=Vector2(target_width, target_width);
	if (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.CONE):
		piece_prefabs=Parameter.CONE_PIECE_PREFABS;
		Parameter.PIECE_SIZE=Vector2(target_width, target_width*Parameter.STANDARD_RIM_RATIO);
	var number_player_states=Parameter.PLAYER_ENABLE_STATES[GameDataManager.SAVEDATA.number_players-Parameter.MIN_PLAYERS];
	for i in range(Parameter.MAX_PLAYERS):
		var shown:bool=number_player_states[i];
		if(!shown):
			continue;
		var piece_prefab=piece_prefabs[i];
		for j in range(Parameter.MAX_PIECES):
			var tile_on=location_to_tile(player_locations[i][j], i, j);
			if (self.player_pieces[i][j]!=null):
				var _piece=self.player_pieces[i][j];
				_piece.tile_parent.remove_piece(_piece);
				_piece.queue_free();
				self.player_pieces[i][j]=0;
				
			var piece=piece_prefab.instantiate();
			tile_on.add_piece(piece);
			piece.name="Piece_"+str(i)+"_"+str(j);
			piece.player_id=i;
			piece.piece_id=j;
			
			# add the newly available piece
			self.player_pieces[i][j]=piece;
	previous_pad_id=-1; # triggers redraw of markers

func resolve_same_location_scale(self_player_id:int, other_player_id:int, other_loc:int):
	""" 
	resolves other_loc onto the location scale of self_player_id
	so that the other_loc has a value it would have had if it belonged to self_player_id
	while maintaining screen position
	"""
	var player_shift_div=int(Parameter.MAX_DIVISIONS/float(Parameter.MAX_PLAYERS));
	var a=(other_player_id-self_player_id)*player_shift_div;
	var a_c=0;
	var mod=other_loc%(Parameter.MAX_DIVISIONS+1);
	if (a>0):
		a_c=Parameter.MAX_DIVISIONS-a;
		if (mod>=a_c):
			return other_loc-a_c;
		else:
			return other_loc+a;
	elif (a<0):
		a_c=-a;
		if (mod>=a_c):
			return other_loc-a_c;
		else:
			return other_loc+(Parameter.MAX_DIVISIONS+a);
	return other_loc;
	
func in_safe_zone(player_id:int, piece_id:int)->bool:
	# checks whether location for above params is in its safe zones
	return safe_locations.find(self.player_locations[player_id][piece_id])!=-1

func piece_in_safe_zone(piece):
	return  in_safe_zone(piece.player_id, piece.piece_id);

func location_to_tile(location:int, player_id:int, piece_id:int):
	# gets collision tile for player given zero-indexed location
	if(location<=Parameter.YARD_LOCATION):
		return yard_collision_tiles[player_id][piece_id];
	elif(location>Parameter.YARD_LOCATION && location<Parameter.HOME_LOCATION-1):
		location=(location-1)+Parameter.BOARD_SHIFT+location_offsets[player_id];
		var sector_index:int = int((location-Parameter.BOARD_SHIFT-location_offsets[player_id])/Parameter.MAX_DIVISIONS);
		var tile_index:int = location%Parameter.MAX_DIVISIONS;
		var index:int = (sector_index*Parameter.MAX_DIVISIONS+tile_index);
		return sector_collision_tiles[index];
	elif(location==Parameter.HOME_LOCATION-1):
		return entrance_tiles[player_id];
	else:
		return home_collision_tiles[player_id][piece_id];

func get_player_completion_percentage(_player_id:int)->int:
	# returns percentage of completion for player_id
	var max_val:float=Parameter.HOME_LOCATION*Parameter.MAX_PIECES;
	var sum_val:float=0;
	for i in range(Parameter.MAX_PIECES):
		sum_val+=self.player_locations[_player_id][i];
	var ratio:float = sum_val/max_val;
	return int(ratio*100);

func apply_load_state(lock_collision:bool=true):
	# applies the state contained in SAVEDATA object
	if (lock_collision):
		Parameter.LOCK_COLLISION=true;
	for i in range(GameDataManager.SAVEDATA.number_players):
		var id:int=GameDataManager.SAVEDATA.player_mapping[i];
		Parameter.PLAYER_COMPLETION_PERCENTAGES[id]=get_player_completion_percentage(id); # locations preloaded in _init
		for j in range(Parameter.MAX_PIECES):
			var tile = location_to_tile(GameDataManager.SAVEDATA.location_matrix[id][j], id, j);
			tile.add_piece(self.player_pieces[id][j]);
	if (lock_collision):
		Parameter.LOCK_COLLISION=false;

func move_location(_player_id:int, _piece_id:int, location:int):
	# performs a single piece move render for any current loactaion to location
	if (location<Parameter.YARD_LOCATION || location>Parameter.HOME_LOCATION):
		return;
	var current_location:int = self.player_locations[_player_id][_piece_id];
	if (location!=current_location):
		# remove piece from current tile
		var current_tile = self.location_to_tile(current_location, _player_id, _piece_id);
		var piece_to_move = self.player_pieces[_player_id][_piece_id];
		current_tile.remove_piece(piece_to_move);
		self.player_locations[_player_id][_piece_id] = location;
		var new_tile = self.location_to_tile(location, _player_id, _piece_id);
		new_tile.add_piece(piece_to_move);

func move_player_piece(piece:Piece, steps:int):
	move_location(piece.player_id, piece.piece_id, self.player_locations[piece.player_id][piece.piece_id]+steps);

func get_movable_states(roll:int)->Array:
	# returns bool of pieces of current player that can move given current roll
	var movable_states:Array = CoreUtils.create_array_1d(Parameter.MAX_PIECES);
	for i in range(Parameter.MAX_PIECES):
		movable_states[i]=false;
		var loc:int=self.player_locations[Parameter.CURRENT_PLAYER_ID][i];
		if (loc==Parameter.YARD_LOCATION):
			if(roll==6):
				movable_states[i] = true;
		elif(loc!=Parameter.HOME_LOCATION):
			var diff_home:int = Parameter.HOME_LOCATION-loc;
			if (roll<=diff_home):
				movable_states[i]=true;
	return movable_states;

func go_to_next_player_index():
	var _id=GameDataManager.SAVEDATA.player_mapping[GameDataManager.SAVEDATA.active_player_index];
	GameDataManager.SAVEDATA.active_player_index = (GameDataManager.SAVEDATA.active_player_index+1)%GameDataManager.SAVEDATA.number_players;
	
func start_moving(steps:int):
	# triggers motion to start for any current piece
	Parameter.STATE_HANDLER.set_state("MOVING");
	self.move_step_elapse=0.0;
	self.moving_location_steps=0;
	self.target_location_steps=steps;
	
func on_start_cycle():
	# sets up for a fresh cycle by clearing ALL states
	self.move_step_elapse=0.0;
	self.cycle_pause_elapse=0.0;
	self.move_type=MOVE_TYPE.NONE;
	self.same_rolls=false;
	self.can_move=false;
	# clear Dice
	Events.emit_signal("trigger_reset_roll");
	# re-render tiles to put current player pieces on top
	for i in range(Parameter.MAX_PIECES):
		var piece_tile = location_to_tile(self.player_locations[Parameter.CURRENT_PLAYER_ID][i], Parameter.CURRENT_PLAYER_ID, i);
		if (len(piece_tile.pieces)>1):
			piece_tile.place_pieces_on_tile();
	GameDataManager.CONFIGDATA.reset_game_speed();
	Parameter.reset_cycle();

func force_non_waiting_move_to_next():
	# peforms a move_to_next that has no delay
	self.cycle_pause_elapse=self.cycle_pause_delay;
	go_to_next_player_index();
	on_start_cycle();
	Parameter.STATE_HANDLER.set_state("START_CYCLE");
	

func get_backward_location(location:int)->int:
	# returns the location with a lowered sector
	var new_location = location-Parameter.BACK_STEPS;
	if (new_location<0):
		return 0;
	return new_location;
	
func get_roll_movable_counts()->Array:
	# returns count of movable pieces for each pad
	var _roll_movable_counts:Array=CoreUtils.create_array_1d(Parameter.MAX_DIE, 0);
	for i in range(Parameter.MAX_DIE):
		var _roll=Parameter.ROLLS[i];
		var movable_states = get_movable_states(_roll);
		_roll_movable_counts[i]=0;
		for j in range(Parameter.MAX_PIECES):
			_roll_movable_counts[i] += int(movable_states[j]);
	return _roll_movable_counts;

func update_external_states():
	# used to send broadcast for online
	pass;

func _on_back_pressed(): 
	# send signal to game_layer
	if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
		MultiplayerConnectHandler.reset_networking();
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn");
	
func check_if_pause_elapse_expired(_elapse:float=12.0):
	"""
	detects if the game lost focus
	returns true if the game lost focus for more than elapse
	"""
	if (!Parameter.GAME_READY):
		return;
	if (last_pause_time==null):
		last_pause_time=Time.get_unix_time_from_system();
		return false;
	var diff=Time.get_unix_time_from_system()-last_pause_time;
	last_pause_time=Time.get_unix_time_from_system();
	if (diff>_elapse):
		return true;
		
func reset_pause_elapse_time():
	last_pause_time=null;
	
func _notification(what):
	if (what==NOTIFICATION_WM_CLOSE_REQUEST):
		GameUtils.on_exit_game();
	elif (what==NOTIFICATION_WM_GO_BACK_REQUEST):
		if (Parameter.PANEL_ACTIVE):
			Events.emit_signal("trigger_close_panel");
			return;
		_on_back_pressed();

func _process(_delta):
	if (Parameter.GAME_PAUSED || !Parameter.GAME_READY):
		return;
	
	if (GameDataManager.CONFIGDATA.piece_type_changed && !Parameter.PLACING_PIECE):
		if (!swapping_piece):
			add_pieces_to_scene();
			GameDataManager.CONFIGDATA.piece_type_changed=false;
			swapping_piece=false;
	
	if(swapping_piece): # disable activities that would disrupt the piece
		return;
		
	if(Parameter.STATE_HANDLER.check_if_state_is("START_CYCLE")):
		Parameter.CURRENT_PLAYER_ID=GameDataManager.SAVEDATA.player_mapping[GameDataManager.SAVEDATA.active_player_index];
		Parameter.GAME_READY=true;
		update_external_states();
		# check if all have completed & end
		var completed_count=0;
		for i in range(Parameter.MAX_PLAYERS):
			if (!Parameter.PLAYER_COMPLETION_STATES[i]):
				var all_at_home=(Parameter.PLAYER_COMPLETION_PERCENTAGES[i]==100);
				Parameter.PLAYER_COMPLETION_STATES[i]=all_at_home;
			if (Parameter.PLAYER_COMPLETION_STATES[i]):
				completed_count+=1;
		var all_completed=(completed_count==GameDataManager.SAVEDATA.number_players);
		if (Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.CURRENT_PLAYER_ID]==100):
			Parameter.PLAYER_COMPLETION_STATES[Parameter.CURRENT_PLAYER_ID]=true;
			if (self.player_completion_listing.find(Parameter.CURRENT_PLAYER_ID)==-1): # register order
				self.player_completion_listing[player_completion_index]=Parameter.CURRENT_PLAYER_ID;
				Events.emit_signal("update_completion_listing", player_completion_listing);
				player_completion_index+=1;
			if (Parameter.CURRENT_PLAYER_ID==Parameter.SELF_PLAYER_ID || all_completed): # -v
				Parameter.SELF_COMPLETED=true;
				
		if (Parameter.SELF_COMPLETED):  # to trigger panel
			if (all_completed || !end_game_popup_shown):
				end_game_popup_shown=true;
				var is_online=(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE);
				if (!is_online):
					GameDataManager.clear_file_savedata();
				if (all_completed || !is_online):
					if(all_completed):
						Parameter.GAME_COMPLETED=true;
					Events.emit_signal("show_interstitial_ad");
					await get_tree().create_timer(0.15).timeout;
					Events.emit_signal("show_panel_game_over");
					Parameter.GAME_PAUSED=true;
				return;
		
		if (Parameter.PLAYER_COMPLETION_STATES[Parameter.CURRENT_PLAYER_ID] || Parameter.PLAYER_CONNECTION_STATES[Parameter.CURRENT_PLAYER_ID]==Parameter.CONNECTION_STATE.DISCONNECTED):
			force_non_waiting_move_to_next();
		else:
			on_start_cycle();
			Parameter.STATE_HANDLER.set_state("AWAIT_ROLL");
