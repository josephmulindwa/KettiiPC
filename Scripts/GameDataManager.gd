extends Node

"""class for loading Data from Files"""

var SAVEDATA:SaveData=null;
var CONFIGDATA:ConfigData=null;
var LANGUAGEDATA=null;
var ASSETS=null;
var is_new_game:bool=false; # indicates a freshly installed game with no savefile
var _save_filename:String="user://savedata.tres";
var _config_filename:String="user://configdata.json";
var _language_filename:String="res://languages.json";

func read_savedata():
	# reads and loads save data;
	if (!FileAccess.file_exists(_save_filename)):
		reset_savedata();
		is_new_game=true;
		return;
	var file=FileAccess.open(_save_filename, FileAccess.READ);
	var save_string=file.get_as_text();
	file.close();
	reset_savedata();
	var loaded=false;
	if (save_string!=null && len(save_string)>0):
		loaded=SAVEDATA.from_string(save_string);
	SAVEDATA.loaded=loaded;
	if (!loaded):
		clear_savedata();

func write_savedata(savedata:SaveData)->bool:
	# writes save data to file
	if (savedata==null):
		return false;
	var save_string=savedata.as_string();
	var file=FileAccess.open(_save_filename, FileAccess.WRITE);
	file.store_string(save_string);
	file.close();
	return true;

func write_current_savedata():
	write_savedata(SAVEDATA);	

func reset_savedata():
	if (SAVEDATA==null):
		SAVEDATA=SaveData.new();
		add_child(SAVEDATA);
		SAVEDATA.name="SaveDataObject";
	SAVEDATA.reset();

func clear_file_savedata():
	# empties the savedata file
	var file=FileAccess.open(_save_filename, FileAccess.WRITE);
	file.store_string("");
	file.close();

func clear_savedata():
	# empties the savedata file, and clears the ram object
	clear_file_savedata();
	reset_savedata();

func write_configdata(configdata:ConfigData)->bool:
	if (configdata==null):
		return false;
	var config_string=configdata.as_string();
	var file=FileAccess.open(_config_filename, FileAccess.WRITE);
	file.store_string(config_string);
	file.close();
	return true;

func write_current_configdata():
	write_configdata(CONFIGDATA);

func read_configdata():
	# reads and loads save data;
	if (!FileAccess.file_exists(_config_filename)):
		reset_configdata();
		return;
	var file=FileAccess.open(_config_filename, FileAccess.READ);
	var config_string=file.get_as_text();
	file.close();
	reset_configdata();
	var loaded=false;
	if (config_string!=null && len(config_string)>0):
		loaded=CONFIGDATA.from_string(config_string);
	CONFIGDATA.loaded=loaded;
	if (!loaded):
		clear_configdata();

func reset_configdata():
	if (CONFIGDATA==null):
		CONFIGDATA=ConfigData.new();
		add_child(CONFIGDATA);
		CONFIGDATA.name="ConfigDataObject";
	CONFIGDATA.reset();

func clear_configdata():
	var file=FileAccess.open(_config_filename, FileAccess.WRITE);
	file.store_string("");
	file.close();
	reset_configdata();

func read_languagedata():
	# reads and loads save data;
	if (!FileAccess.file_exists(_language_filename)):
		LANGUAGEDATA=null;
		return;
	var file=FileAccess.open(_language_filename, FileAccess.READ);
	var json_string=file.get_as_text();
	file.close();
	if (json_string!=null && len(json_string)>0):
		var json = JSON.new();
		var error = json.parse(json_string);
		if (error==OK):
			LANGUAGEDATA=json.data;
			return;
		else:
			LANGUAGEDATA=null;
			return;
