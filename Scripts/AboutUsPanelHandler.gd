extends NinePatchRect

var privacy_link="https://www.anileconn.com/project/ketti/privacy.html";
var godot_link="https://godotengine.org/license/";
# https://godotengine.org/license/#:~:text=Note%20however%20that%20the%20Godot,statement%20somewhere%20in%20your%20documentation.

func _ready():
	self.visible=false;
	var close_button=$CloseButton;
	var privacy_policy_button=$ButtonPrivacyPolicy;
	var godot_button=$MadeWithGodotContainer/MadeWithLabel/ButtonGodotLink;
	
	close_button.pressed.connect(_on_close_button_pressed);
	privacy_policy_button.pressed.connect(_on_privacy_policy_button_pressed);
	godot_button.pressed.connect(_on_godot_button_pressed);

func _on_privacy_policy_button_pressed():
	OS.shell_open(privacy_link);

func _on_godot_button_pressed():
	OS.shell_open(godot_link);

func _on_close_button_pressed():
	Events.emit_signal("hide_menu_panel", "about_us");
