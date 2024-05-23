extends CanvasLayer

var asset_data;
var asset_keys:Array;
var current_index:int=0;
var previous_index:int=-1;
var previous_total_progress=0;
var total_progress=0;

func _ready():
	DisplayServer.screen_set_keep_on(false);
	
	asset_data={
		"red_rim_piece":"res://Prefabs/piece_red_rim.tscn",
		"blue_rim_piece":"res://Prefabs/piece_blue_rim.tscn",
		"yellow_rim_piece":"res://Prefabs/piece_yellow_rim.tscn",
		"green_rim_piece":"res://Prefabs/piece_green_rim.tscn",
		"any_rim_piece":"res://Prefabs/piece_any_rim.tscn",
		
		"red_cone_piece":"res://Prefabs/piece_red_cone.tscn",
		"blue_cone_piece":"res://Prefabs/piece_blue_cone.tscn",
		"yellow_cone_piece":"res://Prefabs/piece_yellow_cone.tscn",
		"green_cone_piece":"res://Prefabs/piece_green_cone.tscn",
		"any_cone_piece":"res://Prefabs/piece_any_cone.tscn",
		
		"player_computer_sprite":"res://Sprites/Chip.png",
		"player_human_sprite":"res://Sprites/PersonIconTransparent.png",
		
		"sector_tile_i":"res://Prefabs//tile_parent_sector_i.tscn",
		"sector_tile_ii":"res://Prefabs//tile_parent_sector_ii.tscn",
		"sector_tile_iii":"res://Prefabs//tile_parent_sector_iii.tscn",
		"sector_tile_iv":"res://Prefabs//tile_parent_sector_iv.tscn",
		
		"timestamp_timer":"res://Scripts/TimestampTimer.gd",
		"toggle_manager":"res://Scripts/ToggleManager.gd",
		"state_handler":"res://Scripts/StateHandler.gd",
		"circle_x_tick":"res://Sprites/CircleXTick.png",
		"circle_x_null":"res://Sprites/CircleXNull.png",
		
		"game_over_soundfx":"res://Audio/GameWinAudio.mp3",
		"game_ended_soundfx":"res://Audio/GameEndedAudio.mp3",
		"piece_move_soundfx":"res://Audio/Move.mp3",
		"piece_collide_soundfx":"res://Audio/Collide.mp3",
		"dice_roll_soundfx":"res://Audio/DiceSound.mp3",
		"reached_home_soundfx":"res://Audio/ReachedHome.mp3",
		
		"piece_marker_effect":"res://Prefabs/piece_marker_parent.tscn",
		"piece_after_effect":"res://Prefabs//after_image.tscn",
		"piece_explosion_effect":"res://Prefabs//explosion_rim_image.tscn",
		
		"main_menu_scene":"res://Scenes/main_menu_scene.tscn" # should be last
	}
	
	asset_keys=asset_data.keys();
	GameDataManager.read_languagedata();
	GameDataManager.ASSETS={};

func update_load_percentage():
	var _ratio=total_progress/float(len(asset_keys));
	var percentage=int(_ratio*100);
	$PercentageLabel.text=str(percentage)+"%";

func _process(_delta):
	var current_asset_key=asset_keys[current_index];
	var error=OK;
	if (previous_index!=current_index):
		error=ResourceLoader.load_threaded_request(
			asset_data[current_asset_key], "", false, 
			ResourceLoader.CACHE_MODE_IGNORE
		);
		previous_index=current_index;
	var load_progress;
	var temp:Array=[];
	if (error!=OK):
		load_progress=1;
	var load_status=ResourceLoader.load_threaded_get_status(asset_data[current_asset_key], temp);
	if (load_status==0 || load_status==2):
		load_progress=1;
		error=FAILED;
	else:
		load_progress=temp[0];
	total_progress=previous_total_progress+temp[0]; # gives exact progress 
	if(load_status==ResourceLoader.THREAD_LOAD_LOADED || error!=OK):
		current_index+=1;
		previous_total_progress+=load_progress;
		var packed=ResourceLoader.load_threaded_get(asset_data[current_asset_key]);
		if (current_index>=len(asset_keys)):
			get_tree().change_scene_to_packed(packed);
		else:
			GameDataManager.ASSETS[current_asset_key]=packed;			
	update_load_percentage();
