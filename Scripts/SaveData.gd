extends Node;

class_name SaveData;

var loaded;
var number_players:int;
var active_player_index:int; # index in mapping of active player
var active_game_mode:int;
var player_mapping:Array;
var location_matrix:Array;

func _init():
	self.reset();

func reset():
	self.loaded=false;
	self.number_players=Parameter.MAX_PLAYERS;
	self.active_player_index=0;
	self.active_game_mode=Parameter.GAME_MODE.TABLE;
	self.location_matrix=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS, Parameter.MAX_PIECES, 0);
	self.player_mapping=[];
	for i in range(Parameter.MAX_PLAYERS):
		self.player_mapping.append(i);	

func repr():
	var s={"loaded":loaded,"number_players":number_players,"active_index":active_player_index,"mapping":player_mapping,"location_matrix":location_matrix,"active_game_mode":active_game_mode};
	return s;
	
func as_string():
	# encodes self into string
	var s:String="";
	s+=CoreUtils.to_hex(self.active_game_mode);
	s+=CoreUtils.to_hex(self.number_players);
	s+=CoreUtils.to_hex(self.active_player_index);
	s+=CoreUtils.array_to_encoded_string(self.player_mapping);
	var arr = [];
	for i in range(len(self.location_matrix)):
		for j in range(len(self.location_matrix[i])):
			arr.append(self.location_matrix[i][j]);
	s+=CoreUtils.array_to_encoded_string(arr);
	return s;

func _to_string():
	return as_string();

func from_string(s:String)->bool:
	# fills self from string
	var span=CoreUtils.WORDSIZE;
	var temp:String;
	
	# read active_game_mode
	temp=s.left(span);
	s=s.substr(span);
	if (len(temp)<span):
		return false;
	self.active_game_mode=temp.hex_to_int();
	
	# read number players
	temp=s.left(span);
	s=s.substr(span);
	if (len(temp)<span):
		return false;
	self.number_players=temp.hex_to_int();
	
	# read active player index
	temp=s.left(span);
	s=s.substr(span);
	if (len(temp)<span):
		return false;
	self.active_player_index=temp.hex_to_int();
	
	# read player_mapping
	span=(Parameter.MAX_PLAYERS+2)*CoreUtils.WORDSIZE;
	temp=s.left(span);
	s=s.substr(span);
	if (len(temp)<span):
		return false;
	self.player_mapping=CoreUtils.encoded_string_to_array(temp);
	if (len(self.player_mapping)!=Parameter.MAX_PLAYERS):
		return false;
	
	# read location matrix
	span=(Parameter.MAX_PLAYERS*Parameter.MAX_PIECES+2)*CoreUtils.WORDSIZE;
	temp=s.left(span);
	s=s.substr(span);
	if (len(temp)<span):
		return false;
	var arr=CoreUtils.encoded_string_to_array(temp);
	if (len(arr)!=Parameter.MAX_PLAYERS*Parameter.MAX_PIECES):
		return false;
	self.location_matrix=CoreUtils.create_array_2d(Parameter.MAX_PLAYERS, Parameter.MAX_PIECES);
	
	var k=0;	
	for i in range(Parameter.MAX_PLAYERS):
		for j in range(Parameter.MAX_PIECES):
			self.location_matrix[i][j]=arr[k];
			k+=1;
	return true;
