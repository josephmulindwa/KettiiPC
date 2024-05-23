extends NinePatchRect

func _ready():
	name="TutorialsLayer";
	var link_button=$ButtonTutorialsLink;
	var close_button=$CloseButton;
	link_button.pressed.connect(on_link_button_pressed);
	close_button.pressed.connect(on_close_button_pressed);

func on_link_button_pressed():
	OS.shell_open(Parameter.TUTORIALS_LINK);

func on_close_button_pressed():
	Events.emit_signal("hide_menu_panel", "tutorialpanel");
