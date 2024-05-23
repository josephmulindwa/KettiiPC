extends SubViewport

"""
handles logic to roll both die
""" 
var rolling:bool=false;
var min_rotation:float=8.0;
var max_rotation:float=31.0;
var roll_cache:Array=CoreUtils.create_array_1d(Parameter.MAX_DIE);
var die:Array=CoreUtils.create_array_1d(Parameter.MAX_DIE);
var roll_elapse:float=0.0;
var roll_delay:float=0.4; # controls duration of roll;
var preset_rolls:Array; # if not -1, sets the roll and ignores random value
var anomaly_count:int=0; # count of shady dice rolls
var max_anomaly_count:int=3;
var roll_orientation_none = Vector3(45.0, 45.0, 45.0);
var roll_orientation_eulers:Array[Vector3] = [
	Vector3(0.0, 180.0, 90.0), Vector3(0.0, 270.0, 0.0), Vector3(-90.0, 0.0, 0.0),
	Vector3(0.0, 180.0, 0.0), Vector3(0.0, 90.0, 0.0), Vector3(90.0, -90.0, 0.0)
];

func _ready():
	die[0]=$DiceRender/white_dice1;
	die[1]=$DiceRender/white_dice2;
	reset_roll();
	for i in range(Parameter.MAX_DIE):
		rotate_to_match_roll(i, Parameter.ROLLS[i]);
	Events.trigger_roll.connect(_on_trigger_roll_request);
	Events.trigger_reset_roll.connect(reset_roll);
	
func _on_trigger_roll_request(presets, as_rpc):
	if (!as_rpc):
		trigger_start_roll(presets);
	else:
		GameUtils.call_rpc_on_peers(trigger_roll_action_rpc, [preset_rolls]);

func reset_preset_rolls():
	self.preset_rolls=[-1, -1];

func set_preset_rolls(rolls):
	self.preset_rolls=rolls;

func single_roll_action(index:int, delta:float):
	# performs a single roll rotation; this is called multiple times to perform a good roll animation
	var roll_value_x = randf_range(self.min_rotation, self.max_rotation)*delta;
	var roll_value_y = randf_range(self.min_rotation, self.max_rotation)*delta;
	var roll_value_z = randf_range(self.min_rotation, self.max_rotation)*delta;
	var spin_rate = Parameter.MAX_SPINRATE;
	perform_rotation(index, Vector3(roll_value_x*spin_rate, roll_value_y*spin_rate, roll_value_z*spin_rate));

func generate_roll(maxv:int=6)->int:
	# uses random generator to generate value
	var value:int = randi_range(1, maxv);
	return value;

func generate_rolls():
	# returns a list of rolls 
	var arr=[];
	for i in range(Parameter.MAX_DIE):
		arr.append(generate_roll())
	return arr;

func rotate_to_match_roll(index:int, roll:int):
	# rotates dice at index to match roll;
	if (roll<1 || roll>6):
		set_to_rotation(index, self.roll_orientation_none);
	else:
		set_to_rotation(index, self.roll_orientation_eulers[roll-1]);
		
func perform_rotation(index:int,euler:Vector3):
	var euler_radians_arr=[deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z)];
	var rotation_basises = [Vector3(1,0,0), Vector3(0,1,0), Vector3(0,0,1)];
	var indexer = [];
	for i in range(len(euler_radians_arr)):
		indexer.append(i);
	#indexer.shuffle(); # generate a random order of rotation
	# perform randomized rotation
	for i in range(len(euler_radians_arr)):
		var idx=indexer[i];
		die[index].rotate(rotation_basises[idx], euler_radians_arr[idx]);

func set_to_rotation(index:int, euler:Vector3):
	var euler_radians=Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z));
	die[index].set_rotation(euler_radians);

func trigger_start_roll(presets=[]):
	"""
	triggers start of roll
	if presets is not empty; presets are set up
	"""
	if (!Parameter.STATE_HANDLER.check_if_state_is("AWAIT_ROLL")):
		return;
	Parameter.STATE_HANDLER.disable_state("AWAIT_ROLL");
	if(self.rolling):
		return;
	reset_roll();
	# generate presets
	if (len(presets)>0):
		self.preset_rolls=presets;
	else:
		self.preset_rolls=generate_rolls();
	Events.emit_signal("play_sound", "DICE_ROLL");	
	self.rolling=true;
	self.roll_elapse=0.0;

@rpc("any_peer", "call_remote", "reliable")
func trigger_roll_action_rpc(_preset_rolls, rpcc=GameUtils.rpc_cycle_counter):
	if (!GameUtils.check_rpc_counter_validity(rpcc)):
		return;
	GameUtils.rpc_cycle_counter=rpcc;
	trigger_start_roll(_preset_rolls);

func generate_non_anomalous_rolls():
	# generates rolls that are non-anomalous; no 6, no same rolls
	var generated=CoreUtils.create_array_1d(Parameter.MAX_DIE);
	for i in range(Parameter.MAX_DIE):
		if (i==0):
			generated[i]=generate_roll(5);
		else:
			generated[i]=generate_roll(5);
			while (generated[i]==generated[i-1]):
				generated[i]=generate_roll(5);
	return generated;
				
func get_roll(index:int):
	# returns already cached rolls
	return Parameter.ROLLS[index];

func reset_roll():
	for i in range(Parameter.MAX_DIE):
		Parameter.ROLLS[i]=0;
		self.roll_cache[i]=-1;
	reset_preset_rolls();

func detect_update_anomaly() -> bool:
	"""
	detects if all rolls are same or 6 & updates anomaly count
	returns whether an anomaly was detected in the current call
	"""
	if (Parameter.PLAYER_TYPES[Parameter.CURRENT_PLAYER_ID]==Parameter.PLAYER_TYPE.CPU):
		var all_same=true;
		var has_six=false;
		var target=Parameter.ROLLS[0];
		for i in range(Parameter.MAX_DIE):
			if (Parameter.ROLLS[i]!=target):
				all_same=false;
			if (Parameter.ROLLS[i]==6):
				has_six=true;
		if (all_same || has_six):
			anomaly_count+=1;
			return true;
	return false;

func _generate_random_max_anomaly_count():
	return randf_range(2, 5);

func _process(delta):
	if (!Parameter.GAME_READY):
		return;
	if (Parameter.GAME_PAUSED):
		return;
	if (Parameter.STATE_HANDLER.check_if_state_is("START_CYCLE")):
		self.anomaly_count=0;
	if(self.rolling):
		self.roll_elapse+=delta;
		for i in range(Parameter.MAX_DIE):
			single_roll_action(i, delta);
		if(self.roll_elapse>=self.roll_delay):
			for i in range(Parameter.MAX_DIE):
				if (self.preset_rolls[i]!=-1):
					Parameter.ROLLS[i]=self.preset_rolls[i];
				else:
					Parameter.ROLLS[i]=generate_roll();
			
			# anomaly correction
			var is_anomaly=detect_update_anomaly();
			if (is_anomaly && anomaly_count>=max_anomaly_count):
				Parameter.ROLLS=generate_non_anomalous_rolls();
				max_anomaly_count=int(_generate_random_max_anomaly_count());
			Parameter.ROLLS.sort_custom(func(a, b): return a > b) # sort descending
			self.rolling=false;
			Parameter.STATE_HANDLER.set_state("ROLLED");
	else:
		for i in range(Parameter.MAX_DIE):
			var roll = Parameter.ROLLS[i];
			if (roll!=self.roll_cache[i]):
				rotate_to_match_roll(i, roll);
				self.roll_cache[i]=roll;
