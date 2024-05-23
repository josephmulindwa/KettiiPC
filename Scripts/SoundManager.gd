extends Node

var streams={};
var _queue_freeables:Array=[];

func _ready():
	streams={
		"GAME_OVER":{"obj":null, "res":"game_over_soundfx"},
		"PIECE_MOVE":{"obj":null, "res":"piece_move_soundfx"},
		"PIECE_EXPLODE":{"obj":null, "res":"piece_collide_soundfx"},
		"DICE_ROLL":{"obj":null, "res":"dice_roll_soundfx"},
		"REACHED_HOME":{"obj":null, "res":"reached_home_soundfx"}
	};
	
	for stream in streams.keys():
		streams[stream].obj=AudioStreamPlayer.new();
		add_child(streams[stream].obj);
		_queue_freeables.append(streams[stream].obj);
		var res_key=streams[stream].res;
		streams[stream].obj.stream=GameDataManager.ASSETS[res_key];

	Events.play_sound.connect(_on_play_sound_request);
	Events.pause_sound.connect(_on_pause_sound_request);
	self.tree_exiting.connect(
		func(): GameUtils.free_items(_queue_freeables);
	);

func _on_play_sound_request(sound_id):
	if (!GameDataManager.CONFIGDATA.sound_on):
		return;
	if (sound_id in streams.keys()):
		streams[sound_id].obj.play();

func _on_pause_sound_request():
	for stream in streams.keys():
		streams[stream].obj.stop();
