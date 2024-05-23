extends Node

var languages_panel;
var about_us_panel;
var inner_panel_active:bool=false;
var main_panel;
var languages_button;
var languages_button_translate_timer;
var translate_languages;
var translate_language_index=0;

var feedback_email="mailto:tanill.public@gmail.com";
var store_link="https://play.google.com/store/apps/details?id=com.anileconn.kettii";

func _ready():
	var tutorials_button=$OptionsPanel/TutorialsButton;
	languages_button=$OptionsPanel/LanguagesButton;
	var feedback_button=$OptionsPanel/FeedbackButton;
	var about_us_button=$OptionsPanel/AboutUsButton;
	var close_button=$OptionsPanel/CloseButton;
	main_panel=$OptionsPanel;
	languages_panel=$LanguagePanel;
	about_us_panel=$AboutUsPanel;
	
	translate_languages=Parameter.LANGUAGE.values();
	languages_button_translate_timer=Timer.new();
	add_child(languages_button_translate_timer);
	languages_button_translate_timer.timeout.connect(_on_language_button_timer_tick);
	languages_button_translate_timer.wait_time=1.5;
	languages_button_translate_timer.start();
	
	Events.show_panel_settings.connect(
		func(): 
			Parameter.PANEL_ACTIVE=true;
			self.visible=true;
	);
	Events.trigger_close_panel.connect(_on_close_button_pressed);
	Events.hide_menu_panel.connect(_on_hide_menu_panel_request);
	
	tutorials_button.pressed.connect(self._on_tutorials_button_pressed);
	languages_button.pressed.connect(self._on_languages_button_pressed);
	feedback_button.pressed.connect(self._on_feedback_button_pressed);
	about_us_button.pressed.connect(self._on_about_us_button_pressed);
	close_button.pressed.connect(self._on_close_button_pressed);
	self.tree_exiting.connect(
		func(): GameUtils.free_items([languages_button_translate_timer]);
	);

func _on_language_button_timer_tick():
	translate_language_index=(translate_language_index+1)%len(translate_languages);
	languages_button.get_child(0).set_translate_language(translate_languages[translate_language_index]);

func _on_hide_menu_panel_request(panelname):
	if (panelname=="languages"):
		languages_panel.visible=false;
		languages_button_translate_timer.paused=false;
	elif (panelname=="about_us"):
		about_us_panel.visible=false;
	main_panel.visible=true;
	inner_panel_active=false;

func _on_tutorials_button_pressed():
	OS.shell_open(Parameter.TUTORIALS_LINK);
	
func _on_languages_button_pressed():
	main_panel.visible=false;
	languages_panel.visible=true;
	inner_panel_active=true;
	languages_button_translate_timer.paused=true;

func _on_feedback_button_pressed():
	OS.shell_open(feedback_email);

func _on_about_us_button_pressed():
	main_panel.visible=false;
	about_us_panel.visible=true;
	inner_panel_active=true;

func _on_close_button_pressed():
	Parameter.PANEL_ACTIVE=false;
	self.visible=false;
