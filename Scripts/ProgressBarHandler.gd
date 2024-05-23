extends TextureProgressBar

var show_after_ratio=0.9;
var show_after_value;

func _ready():
	self.visible=false;

func _process(_delta):
	if (GameDataManager.SAVEDATA.active_game_mode!=Parameter.GAME_MODE.ONLINE):
		return;
	var current_ratio=0;
	if (Parameter.CYCLE_TIMER_OBJECT!=null):
		current_ratio=Parameter.CYCLE_TIMER_OBJECT.get_remaining_time_ratio();
	var in_showable_range:bool=(current_ratio>0 && current_ratio<=show_after_ratio);
	self.visible=(in_showable_range);
	self.value=(current_ratio*100);
