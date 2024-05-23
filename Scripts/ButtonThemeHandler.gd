extends TranslateHandler

"""gives a button's translated label text a tint when pressed"""

@onready var button=get_parent();
var default_font_shade;
var pressed_font_shade=Color(0.745, 0.745, 0.745);

func _ready():
	super();
	default_font_shade=self.label_settings.font_color;
	
	button.button_down.connect(on_button_pressed);
	button.button_up.connect(on_button_released);
	
func on_button_pressed():
	self.label_settings.font_color=pressed_font_shade;

func on_button_released():
	self.label_settings.font_color=default_font_shade;
