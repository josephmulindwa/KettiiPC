extends NinePatchRect

var languages:Array;
var language_clickables:Array;
var language_changed:bool=true;

var enable_tint_colors={"font":Color(1.0, 1.0, 1.0, 1), "shadow":Color(0.3, 0.3, 0.3, 1)};
var disable_tint_colors={"font":Color(0.5, 0.5, 0.5, 1), "shadow":Color(0.9, 0.9, 0.9, 1)};

func _ready():
	visible=false;
	var close_button=$CloseButton;
	language_clickables=[
		$ButtonEnglish, $ButtonFrench, $ButtonHindi, $ButtonItalian,
		$ButtonSpanish, $ButtonJapanese, $ButtonArabic, $ButtonPortuguese
	];
	
	close_button.pressed.connect(self._on_close_button_pressed);
	for i in range(len(language_clickables)):
		language_clickables[i].pressed.connect(
			func():
				_on_language_button_pressed(i);
		);

func _on_close_button_pressed():
	Events.emit_signal("hide_menu_panel", "languages");
	GameDataManager.write_current_configdata();

func _on_language_button_pressed(language):
	GameDataManager.CONFIGDATA.set_language(language);
	language_changed=true;

func enable_clickable(clickable):
	var label=clickable.get_child(0);
	label.modulate=enable_tint_colors.font;

func disable_clickable(clickable):
	var label:Label=clickable.get_child(0);
	label.modulate=disable_tint_colors.font;

func _process(_delta):
	if (language_changed):
		for i in range(len(language_clickables)):
			disable_clickable(language_clickables[i]);
		enable_clickable(language_clickables[GameDataManager.CONFIGDATA.language]);
		language_changed=false;
