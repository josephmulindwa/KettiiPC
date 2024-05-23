extends Control

var player_id;
var player_marker;
var player_name_label;

func _ready():
	player_marker=$PlayerMarker;
	player_name_label=$PlayerNameLabel;
	player_marker.visible=false;

func set_player_id(id):
	player_id=id;
	_on_player_id_changed();

func _on_player_id_changed():
	# sets name, marker, color and image of current item
	var enumeration_bind="";
	var player_name=Parameter.PLAYER_NAMES[player_id];
	if (self.player_id==Parameter.SELF_PLAYER_ID && GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.TABLE):
		player_name="T_YOU";
		set_player_marker(true);
	else:
		if (player_name.contains("T_PLAYER_ENUM:")):
			var splits=player_name.split(":");
			player_name=splits[0];
			enumeration_bind=splits[1];
	var translate_keys:Array[String]=[player_name];
	self.player_name_label.set_enumeration_bind(enumeration_bind);
	self.player_name_label.set_translate_keys(translate_keys);
	
	set_player_color(Parameter.PLAYER_COLORS[player_id]);
	set_player_name(player_name);
	set_player_image();

func set_player_image():
	var player_image=$PlayerImage;
	var is_online=(GameDataManager.SAVEDATA.active_game_mode==Parameter.GAME_MODE.ONLINE);
	if (is_online || Parameter.PLAYER_TYPES[player_id]==Parameter.PLAYER_TYPE.HUMAN || Parameter.PLAYER_TYPES[player_id]==Parameter.PLAYER_TYPE.WEB):
		player_image.texture=GameDataManager.ASSETS["player_human_sprite"];
	elif (Parameter.PLAYER_TYPES[player_id]==Parameter.PLAYER_TYPE.CPU):
		player_image.texture=GameDataManager.ASSETS["player_computer_sprite"];

func set_player_name(player_name):
	# directly sets player_name text without translate
	player_name_label.text=player_name;

func set_player_color(color):
	$ColorMarker.modulate=color;

func set_player_marker(state):
	player_marker.visible=state;

func set_rank(rank):
	$RankLabel.text=str(rank);
