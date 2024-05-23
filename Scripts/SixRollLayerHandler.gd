extends Node;

var action_button;
var title_label;
var close_button;
var _rewarded:bool;
var _reward;

func _ready():
	self.visible=false;
	action_button=$SixRollPanel/ActionButton;
	title_label=$SixRollPanel/MainLabel;
	close_button=$SixRollPanel/CloseButton;
	
	Events.show_panel_six_roll.connect(_on_changed_to_visible);
	Events.trigger_close_panel.connect(_on_close_button_pressed);
	
	action_button.pressed.connect(_on_action_button_pressed);
	close_button.pressed.connect(_on_close_button_pressed);
	show_unrewarded_state();

func _on_changed_to_visible():
	Parameter.PANEL_ACTIVE=true;
	self.visible=true;
	show_unrewarded_state();

func show_rewarded_state(reward=[]):
	## !!!!  NOT USED
	title_label.set_translate_key(0, "T_ROLL_A_SIX");
	action_button.get_child(0).set_translate_key(0, "T_ROLL");
	_rewarded=true;
	_reward=reward;
	
func show_unrewarded_state():
	title_label.set_translate_key(0, "T_WATCH_AN_AD_TO_ROLL_A_SIX");
	action_button.get_child(0).set_translate_key(0, "T_CONTINUE");
	_rewarded=false;

func _on_close_button_pressed():
	Parameter.PANEL_ACTIVE=false;
	Parameter.EXITED_BY_AD=false;
	Events.emit_signal("panel_six_roll_disabled");
	self.visible=false;

func _on_action_button_pressed():
	if (!_rewarded):
		Parameter.EXITED_BY_AD=false;
		Events.emit_signal("show_rewarded_ad");
		_on_close_button_pressed();
