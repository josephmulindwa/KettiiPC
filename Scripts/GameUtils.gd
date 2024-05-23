extends Node

var propagated_exit_signal:bool=false;
var rpc_cycle_counter:float=0.0; # this value governs to show which player is ahead of others

func generate_mapping(number_players, start_id):
	# generates player_mapping for current number players
	var l=0; var r=Parameter.MAX_PLAYERS-1;
	var enable_states=Parameter.PLAYER_ENABLE_STATES[number_players-Parameter.MIN_PLAYERS];
	var i=0;
	var k=start_id;
	var state:bool;
	var mapping=CoreUtils.create_array_1d(Parameter.MAX_PLAYERS, 0);
	while (i<Parameter.MAX_PLAYERS):
		state=enable_states[k];
		if (state):
			mapping[l]=k;
			l+=1;
		else:
			mapping[r]=k;
			r-=1;
		k=(k+1)%Parameter.MAX_PLAYERS;
		i+=1;
	return mapping;
		
func seconds_to_minute_string(seconds):
	seconds=int(seconds);
	var minutes_=int(seconds/60);
	var seconds_=seconds%60;
	return "%02d:%02d"%[minutes_, seconds_];
		
func call_rpc_on_peers(callback:Callable, args:Array):
	# performs safe calls on peers that are connected
	var peer_ids=MultiplayerConnectHandler.multiplayer.get_peers();
	args.append(rpc_cycle_counter);
	callback=callback.bindv(args);
	for peer in peer_ids:
		callback.rpc_id(peer);

func check_rpc_counter_validity(rpcc):
	if (rpcc<rpc_cycle_counter): # if sender rpcc is old, decline & tell them to update
		sync_rpc_counter.rpc_id(self.multiplayer.get_remote_sender_id(), rpc_cycle_counter);
		return false;
	return true;

@rpc("any_peer", "call_remote", "reliable")
func sync_rpc_counter(value):
	# updates local rpc cycle counter
	rpc_cycle_counter=value;

func on_exit_game():
	# propagate signal and exit
	if (!self.propagated_exit_signal):
		self.propagated_exit_signal=true;
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST);
	get_tree().quit();

func free_items(items):
	# frees the list of items
	for i in range(len(items)):
		if (items[i]!=null && is_instance_valid(items[i])):
			items[i].queue_free();
	
func get_translated(text_key:String, language:Parameter.LANGUAGE, enumeration_bind=""):
	"""
	receives a known text_key and returns the translation in given language
	e.g get_translated("T_RESUME", 0) -> "resume";
	Enumeration binds are used to replace elements in the translated version that remain constant across languages
	Note that `enumeration_binds` are not translated.
	 returns null on failure
	"""
	if (GameDataManager.LANGUAGEDATA==null || language not in Parameter.LANGUAGE.values()): # key not found
		return null;
	var language_key=Parameter.LANGUAGE.keys()[language];
	if (text_key not in GameDataManager.LANGUAGEDATA.keys()):
		return null;
	if (language_key not in GameDataManager.LANGUAGEDATA[text_key]):
		language_key="DEFAULT"; # the default translation
		if (language_key not in GameDataManager.LANGUAGEDATA[text_key]):
			return null;
	var translated=GameDataManager.LANGUAGEDATA[text_key][language_key];
	if (enumeration_bind!=null):
		if ("ENUM" in GameDataManager.LANGUAGEDATA[text_key].keys()):
			var enumeration_target=GameDataManager.LANGUAGEDATA[text_key]["ENUM"];
			translated=translated.replace(enumeration_target, enumeration_bind);
	return translated;
