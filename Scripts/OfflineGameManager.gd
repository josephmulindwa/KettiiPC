extends GameManagerCore;

func _ready():
	super();
	# update/load all piece locations
	apply_load_state();
	Parameter.GAME_READY=true;

func save_game_state():
	GameDataManager.SAVEDATA.location_matrix=self.player_locations;
	GameDataManager.write_current_savedata();

func get_random_movable_piece(roll:int):
	# pick a random piece among movables of given roll
	var movable_states = get_movable_states(roll);
	var arr=[];
	for i in range(len(movable_states)):
		if (movable_states[i]):
			arr.append(i);
	if (len(arr)==0):
		return -1
	var idx:int = randi_range(0, len(arr)-1);
	return arr[idx]; # move_type, roll_type

func ai_get_random_pad_and_piece():
	var arr_pads:Array=[];
	var arr_pieces:Array=[];
	for i in range(Parameter.MAX_DIE):
		if (Parameter.STATE.ROLLS_USED[i]):
			continue;
		var roll=Parameter.ROLLS[i];
		var selected_piece = get_random_movable_piece(roll);
		if (selected_piece!=-1):
			arr_pads.append(i);
			arr_pieces.append(selected_piece);
	if (len(arr_pads)==0):
		return [-1, -1];
	var idx:int = randi_range(0, len(arr_pads)-1);
	return [arr_pads[idx], arr_pieces[idx]];

func ai_get_best_piece_id(roll:int, is_combination:bool, movable_states:Array)->Array:
	"""
	determines best piece to move given roll and game state
	returns [move_type, index of movable piece]
	"""
	var best_sector:int=-1;
	var best_move_type=MOVE_TYPE.NONE;
	var best_piece_index:int=0;
	var closest_evasion=1+Parameter.MAX_DIE*6;
	var is_avoidant:Array=CoreUtils.create_array_1d(Parameter.MAX_PIECES, false); # avoids being infront of enemy piece
	
	for piece_id_self in range(Parameter.MAX_PIECES):
		if (!movable_states[piece_id_self]):
			continue;
		var self_loc=self.player_locations[Parameter.CURRENT_PLAYER_ID][piece_id_self];
		# if rolled a 6 while at home
		if (self_loc==Parameter.YARD_LOCATION && is_combination):
			continue;
		if (self_loc==Parameter.YARD_LOCATION && roll==6):
			if (best_move_type<MOVE_TYPE.YARD):
				best_move_type=MOVE_TYPE.YARD;
				best_piece_index=piece_id_self;
		elif (roll==(Parameter.HOME_LOCATION-self_loc)):
			if (best_move_type<MOVE_TYPE.HOME):
				best_move_type=MOVE_TYPE.HOME;
				best_piece_index=piece_id_self;
		else: # attack, cascade, move, evade,*avoid
			for p in range(GameDataManager.SAVEDATA.number_players):
				var other_player_id=GameDataManager.SAVEDATA.player_mapping[p];
				for piece_id_other in range(Parameter.MAX_PIECES):
					var other_loc=self.player_locations[other_player_id][piece_id_other];
					if (other_loc<=Parameter.YARD_LOCATION || other_loc>=Parameter.HOME_LOCATION):
						continue;
					# resolve to same metric/scale
					var other_atk_loc=resolve_same_location_scale(Parameter.CURRENT_PLAYER_ID, other_player_id, other_loc);
					var self_evd_loc=resolve_same_location_scale(other_player_id, Parameter.CURRENT_PLAYER_ID, self_loc);
					var diff_attack=other_atk_loc-self_loc;
					var diff_evade=self_evd_loc-other_loc;
					
					# behind enemy with large roll, try to stay behind
					if (other_player_id!=Parameter.CURRENT_PLAYER_ID):
						if (diff_attack>=0 && roll>diff_attack): # AVOIDANT
							is_avoidant[piece_id_self]=true;
					# FORWARD ; with avoidant
					if (other_player_id==Parameter.CURRENT_PLAYER_ID):
						if (best_move_type<=MOVE_TYPE.FORWARD): # forward if !avoidant && !in_safe_zone
							if (!is_avoidant[piece_id_self] && !in_safe_zone(Parameter.CURRENT_PLAYER_ID, piece_id_self)): 
								best_piece_index=piece_id_self;
								best_move_type=MOVE_TYPE.FORWARD;
					if (diff_attack>0 && diff_attack==roll):
						if (other_player_id==Parameter.CURRENT_PLAYER_ID): # CASCADE/fortify
							if (!in_safe_zone(Parameter.CURRENT_PLAYER_ID, piece_id_self)):
								if (best_move_type<MOVE_TYPE.CASCADE):
									best_move_type=MOVE_TYPE.CASCADE;
									best_piece_index=piece_id_self;
						else: # ATTACK
							if (best_move_type<=MOVE_TYPE.ATTACK):
								best_move_type=MOVE_TYPE.ATTACK;
								var sector_id=int(other_loc/Parameter.MAX_DIVISIONS);
								if (sector_id>best_sector): # prioritise higher sectors
									best_sector=sector_id;
									best_piece_index=piece_id_self;
					if (diff_evade>0 && diff_evade<closest_evasion && other_player_id!=Parameter.CURRENT_PLAYER_ID): # EVADE
						closest_evasion=diff_evade;
						if (!in_safe_zone(Parameter.CURRENT_PLAYER_ID, piece_id_self) && best_move_type<MOVE_TYPE.EVADE):
							best_move_type=MOVE_TYPE.EVADE;
							best_piece_index=piece_id_self;
	if (best_move_type==MOVE_TYPE.NONE):
		var mv_inds:Array=[];
		for i in range(len(movable_states)):
			if (movable_states[i]):
				mv_inds.append(i);
		if (len(mv_inds)>0):
			var picked_indx=randi_range(0, len(mv_inds)-1);
			best_move_type=MOVE_TYPE.FORWARD;
			best_piece_index=mv_inds[picked_indx];
	return [best_move_type, best_piece_index];

func ai_get_best_pad_and_piece_id()->Array:
	"""
	determines best pad and piece to move
	"""
	var roll_combinations:Array=[];
	var best_piece_id=-1;
	var best_move_type=MOVE_TYPE.NONE;
	var best_pad_id=-1;
	# roll clean-ups
	var combination=0;
	for i in range(Parameter.MAX_DIE):
		var _roll=Parameter.ROLLS[i];
		if (Parameter.STATE.ROLLS_USED[i]):
			_roll=-1;
		else:
			combination+=_roll;
		roll_combinations.append(_roll);
	roll_combinations.append(combination);
	
	for i in range(len(roll_combinations)):
		var pad_id=i;
		if (i<Parameter.MAX_DIE):
			if (roll_combinations[i]<=0):
				continue;
		else:
			pad_id=randi_range(0, Parameter.MAX_DIE-1);
		var movable_states:Array = get_movable_states(roll_combinations[i]);
		var piece_data=ai_get_best_piece_id(roll_combinations[i], i>=Parameter.MAX_DIE, movable_states); # move_type, piece_id
		if (piece_data[0]>best_move_type):
			best_move_type=piece_data[0];
			best_pad_id=pad_id;
			best_piece_id=piece_data[1];
	return [best_pad_id, best_piece_id];
	
func on_start_cycle():
	# sets up for a fresh cycle by clearing ALL states
	if(!Parameter.SELF_COMPLETED && GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.ONLINE):
		save_game_state();
	super();
	
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

func _process(delta):
	super(delta);
	
	if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_ROLL")):
		if(Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.CPU):
			Events.emit_signal("trigger_roll", [], false);
	
	if (Parameter.STATE_HANDLER.check_if_state_is("ROLLED")):
		# get movable state of all rolls
		var mark_roll=Parameter.ROLLS[0];
		var all_rolls_same=true;
		for i in range(Parameter.MAX_DIE):
			var _roll=Parameter.ROLLS[i];
			all_rolls_same = all_rolls_same && (_roll==mark_roll);
		self.same_rolls=all_rolls_same;
		self.roll_movable_counts = get_roll_movable_counts();
		self.previous_pad_id=-1;
		for i in range(len(self.roll_movable_counts)):
			if (self.roll_movable_counts[i]>0):
				self.can_move=true;
				Parameter.STATE.SELECTED_PAD_ID=i; # enable to mark pad_id
				break;
		if(self.can_move):
			Parameter.STATE_HANDLER.set_state("AWAIT_PAD_SELECT");
		else:
			Parameter.STATE_HANDLER.set_state("END_CYCLE");
		
	if(Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PAD_SELECT")):
		# filter used rolls & pad_cannot_move
		if(Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.HUMAN):
			# allow to pick non-movable pads after-all, they wont be movable
			if(Parameter.STATE.SELECTED_PAD_ID!=previous_pad_id):
				var _roll=Parameter.ROLLS[Parameter.STATE.SELECTED_PAD_ID];
				var movable_states:Array = get_movable_states(_roll);
				on_await_piece_select(movable_states);
				previous_pad_id=Parameter.STATE.SELECTED_PAD_ID;
		else:
			Parameter.STATE_HANDLER.append_state("AWAIT_PIECE_SELECT");
	
	if (Parameter.STATE_HANDLER.check_if_state_is("AWAIT_PIECE_SELECT")): # coupled with moving_x_ids;
		if(Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.CPU):
			var move_data;
			if (GameDataManager.CONFIGDATA.ai_mode==Parameter.AI_MODE.SIMPLE):
				move_data=ai_get_random_pad_and_piece();
			elif (GameDataManager.CONFIGDATA.ai_mode==Parameter.AI_MODE.SMART):
				move_data=ai_get_best_pad_and_piece_id(); # pad_id, piece_id
			Parameter.STATE.SELECTED_PAD_ID=move_data[0];
			Parameter.STATE.MOVING_PIECE_ID=move_data[1];
			Parameter.STATE.MOVING_PLAYER_ID=Parameter.CURRENT_PLAYER_ID;
		if (Parameter.STATE.MOVING_PIECE_ID!=-1 && Parameter.STATE.MOVING_PLAYER_ID!=-1):
			# set up for moving
			if (self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID]==Parameter.YARD_LOCATION):
				# out of base
				self.move_type=MOVE_TYPE.YARD;
				self.moves=1;
			else:
				self.moves=Parameter.ROLLS[Parameter.STATE.SELECTED_PAD_ID];
			start_moving(self.moves);
	
	if (Parameter.STATE_HANDLER.check_if_state_is("MOVING")):
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
			elif (moving_location_steps>target_location_steps):
				forward_pass=false;
				remaining_steps*=-1;
				if(move_steps>remaining_steps):
					move_steps=remaining_steps;
				move_player_piece(moving_piece, -move_steps);
				moving_location_steps-=move_steps;
		
		if (moving_location_steps==target_location_steps):
			var location = self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
			var last_tile:Tile = location_to_tile(location, Parameter.STATE.MOVING_PLAYER_ID, Parameter.STATE.MOVING_PIECE_ID);
			# check if *just reached home
			if(Parameter.STATE.MOVING_PLAYER_ID==Parameter.CURRENT_PLAYER_ID):
				if(location==Parameter.HOME_LOCATION):
					move_type=MOVE_TYPE.HOME;
					Events.emit_signal("play_sound", "REACHED_HOME");
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
						Parameter.STATE.MOVING_PLAYER_ID=colliding_piece.player_id;
						Parameter.STATE.MOVING_PIECE_ID=colliding_piece.piece_id;
						var curr_location=self.player_locations[Parameter.STATE.MOVING_PLAYER_ID][Parameter.STATE.MOVING_PIECE_ID];
						var new_location = get_backward_location(curr_location);
						start_moving(new_location-curr_location);
						# set up speed for moving backwards && reset spped later
						GameDataManager.CONFIGDATA.set_game_speed(0.01, false);
			if (!found_collider):
				GameDataManager.CONFIGDATA.reset_game_speed();
				Parameter.STATE.ROLLS_USED[Parameter.STATE.SELECTED_PAD_ID]=true;
				Parameter.STATE_HANDLER.set_state("END_CYCLE");
			Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.STATE.MOVING_PLAYER_ID] = get_player_completion_percentage(Parameter.STATE.MOVING_PLAYER_ID);
		# set to remainder
		move_step_elapse=move_step_elapse-(move_steps*GameDataManager.CONFIGDATA.game_speed);
		move_step_elapse+=delta;
	
	if(Parameter.STATE_HANDLER.check_if_state_is("END_CYCLE")):
		if (cycle_pause_elapse>=cycle_pause_delay):
			var move_to_next=true;
			if (self.can_move && Parameter.PLAYER_COMPLETION_PERCENTAGES[Parameter.CURRENT_PLAYER_ID]!=100):
				self.roll_movable_counts = get_roll_movable_counts(); # update
				for i in range(Parameter.MAX_DIE):
					if(!Parameter.STATE.ROLLS_USED[i] && self.roll_movable_counts[i]>0):
						Parameter.STATE.SELECTED_PAD_ID=i;
						move_to_next=false;
						Parameter.STATE_HANDLER.set_state("AWAIT_PAD_SELECT");
						break;
			if (move_to_next):
				if (!move_type==MOVE_TYPE.ATTACK && !move_type==MOVE_TYPE.YARD && !move_type==MOVE_TYPE.HOME && !self.same_rolls):
					go_to_next_player_index();
				Parameter.STATE_HANDLER.set_state("START_CYCLE");
			Parameter.STATE_HANDLER.disable_state("END_CYCLE");
			cycle_pause_elapse=0.0;
		cycle_pause_elapse+=delta;
