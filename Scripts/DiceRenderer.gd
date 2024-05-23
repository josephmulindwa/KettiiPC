extends Control

func _process(_delta):
	var texture=$DiceViewport.get_texture();
	$DiceScreen.texture=texture;
	if(Parameter.STATE_HANDLER.check_if_state_is("START_CYCLE")): # anti-flicker on_table
		return;
	if (Parameter.CURRENT_PLAYER_ID in [0,3]):
		self.rotation_degrees=-90.0;
	else:
		self.rotation_degrees=90.0;
