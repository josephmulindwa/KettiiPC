extends Node

class_name ConfigData;

var default_game_speed=0.2;
var loaded;
var ai_mode;
var sound_on;
var blocking_on;
var piece_type;
var game_speed;
var language;
var _game_speed_copy;
var piece_type_changed:bool;

func _init():
	self.reset();

func reset():
	self.loaded=false;
	self.ai_mode=Parameter.AI_MODE.SIMPLE;
	self.sound_on=true;
	self.blocking_on=false;
	self.piece_type=Parameter.PIECE_TYPE.CONE;
	self.game_speed=default_game_speed;
	self.language=Parameter.LANGUAGE.EN;
	self._game_speed_copy=self.game_speed;
	self.piece_type_changed=false;

func as_string():
	var data = {"ai_mode":ai_mode, "sound":sound_on, "blocking":blocking_on, "game_speed":game_speed, "piece_type":piece_type, "language":language};
	return JSON.stringify(data);

func _to_string():
	return as_string();

func set_game_speed(speed:float, save_copy:bool=true):
	if (save_copy):
		self._game_speed_copy=speed;
	self.game_speed=speed;

func reset_game_speed():
	self.game_speed=self._game_speed_copy;

func set_piece_type(_piece_type:Parameter.PIECE_TYPE):
	if (self.piece_type!=_piece_type):
		self.piece_type=_piece_type;
		self.piece_type_changed=true;

func set_language(_language):
	self.language=_language;

func from_string(s:String)->bool:
	# s is json string
	var json=JSON.new();
	var status=json.parse(s);
	if (status!=OK):
		return false;
	var data_read=json.data;
	if (typeof(data_read)!=TYPE_DICTIONARY):
		return false;
	var keys:Array=["ai_mode", "sound", "blocking", "game_speed", "piece_type", "language"];
	for i in range(len(keys)):
		if (keys[i] not in data_read):
			return false;
	if (!str(data_read["ai_mode"]).is_valid_int() || int(data_read["ai_mode"]) not in Parameter.AI_MODE.values()):
		return false;
	else:
		self.ai_mode=int(data_read["ai_mode"]);
	
	if(!str(data_read["game_speed"]).is_valid_float()):
		return false;
	else:
		self.game_speed=float(data_read["game_speed"]);
		self._game_speed_copy=self.game_speed;
	
	if (!str(data_read["piece_type"]).is_valid_int() || int(data_read["piece_type"]) not in Parameter.PIECE_TYPE.values()):
		return false;
	else:
		self.piece_type=int(data_read["piece_type"]);
		self.piece_type_changed=true;
	
	if (!str(data_read["language"]).is_valid_int() || int(data_read["language"]) not in Parameter.LANGUAGE.values()):
		return false;
	else:
		self.language=int(data_read["language"]);
		
	if (str(data_read["sound"]) not in ["true", "false", "0", "1"]):
		return false;
	else:
		self.sound_on=(str(data_read["sound"]) in ["true", "1"]);
	
	if (str(data_read["blocking"]) not in ["true", "false", "0", "1"]):
		return false;
	else:
		self.blocking_on=(str(data_read["blocking"]) in ["true", "1"]);
	return true;
