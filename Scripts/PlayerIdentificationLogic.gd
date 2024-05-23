extends Node

"""
sets the user's name, image, location marker and stats
"""

@export var player_id:int;
var offline_image;
var bound_image_object;
var player_name_label;
var percentage_label;
var progress_bar;
var player_percentage_cache:int=-1;
var location_marker_object;
var marker_location;

func _ready():
	if(Parameter.PLAYER_TYPES[self.player_id]==Parameter.PLAYER_TYPE.NONE):
		self.visible=false;
		return;
	var dp_image_object = $RoundedRect/ContentControl/PlayerImage;
	bound_image_object = $RoundedRect;
	player_name_label = $RoundedRect/PlayerName;
	percentage_label = $RoundedRect/PercentageText;
	location_marker_object=$RoundedRect/ContentControl/LocationMarkerParent/LocationMarker;
	progress_bar=$RoundedRect/ContentControl/ProgressBarControl;
	offline_image=$RoundedRect/ContentControl/OfflineImage;
	location_marker_object.modulate = Parameter.PLAYER_COLORS[player_id];
	
	var player_name=Parameter.PLAYER_NAMES[self.player_id];
	var enumeration_bind="";
	if (self.player_id==Parameter.SELF_PLAYER_ID && GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.TABLE):
		player_name="T_YOU";
	else:
		if (player_name.contains("T_PLAYER_ENUM:")):
			var splits=player_name.split(":");
			player_name=splits[0];
			enumeration_bind=splits[1];
	
	if (len(player_name)>Parameter.MAX_NAME_LENGTH-3): # mainly handles online
		player_name_label.font_size_ratios={};
		for key in Parameter.LANGUAGE.keys():
			player_name_label.font_size_ratios[str(key)]=0.96;
	var translate_keys:Array[String]=[player_name];
	self.player_name_label.set_enumeration_bind(enumeration_bind);
	self.player_name_label.set_translate_keys(translate_keys);
	
	# load image from linked
	if (Parameter.PLAYER_TYPES[self.player_id]==Parameter.PLAYER_TYPE.CPU):
		dp_image_object.texture=GameDataManager.ASSETS["player_computer_sprite"];
	elif (Parameter.PLAYER_TYPES[self.player_id]==Parameter.PLAYER_TYPE.HUMAN || Parameter.PLAYER_TYPES[self.player_id]==Parameter.PLAYER_TYPE.WEB):
		dp_image_object.texture=GameDataManager.ASSETS["player_human_sprite"];
	
	# background color
	var background=$RoundedRect/ContentControl/Background;
	if (Parameter.PLAYER_TYPES[self.player_id]!=Parameter.PLAYER_TYPE.CPU):
		background.visible=true;
		var bgcolor=Parameter.PLAYER_COLORS[self.player_id];
		bgcolor.s=0.3;
		bgcolor.v=0.79;
		background.color=bgcolor;
	else:
		background.visible=false;
	
	# orientation
	if (GameDataManager.SAVEDATA.active_game_mode in [Parameter.GAME_MODE.CPU, Parameter.GAME_MODE.ONLINE]):
		if (Parameter.SELF_PLAYER_ID>=(Parameter.MAX_PLAYERS/2.0)):
			player_name_label.rotation_degrees=180.0;
			$RoundedRect/ContentControl.rotation_degrees=180.0;
		else:
			player_name_label.rotation_degrees=0.0;
			$RoundedRect/ContentControl.rotation_degrees=0.0;
			
func set_percentage(percentage:int):
	var percentage_text:String = str(percentage)+"%";
	self.percentage_label.set_text(percentage_text);
	self.player_percentage_cache = percentage;

func add_marker():
	location_marker_object.play_lerp();
	location_marker_object.visible=true;

func remove_marker():
	location_marker_object.pause_lerp();
	location_marker_object.visible=false;

func _process(_delta):
	if(Parameter.PLAYER_TYPES[self.player_id]==Parameter.PLAYER_TYPE.NONE):
		return;
	progress_bar.visible=(Parameter.CURRENT_PLAYER_ID==player_id);
	
	if (GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE):
		if (len(Parameter.PLAYER_CONNECTION_STATES)>0):
			offline_image.visible=(Parameter.PLAYER_CONNECTION_STATES[self.player_id]==Parameter.CONNECTION_STATE.DISCONNECTED);
	if(player_percentage_cache!=Parameter.PLAYER_COMPLETION_PERCENTAGES[self.player_id]):
		set_percentage(Parameter.PLAYER_COMPLETION_PERCENTAGES[self.player_id]);
	
	# ORIENTATION LOGIC
	if(Parameter.STATE_HANDLER.check_if_state_is("START_CYCLE")): # anti-flicker on_table
		return;
	
	if(self.player_id==Parameter.CURRENT_PLAYER_ID):
		add_marker();
	else:
		remove_marker();
