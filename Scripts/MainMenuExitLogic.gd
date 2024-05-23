extends Node

func _ready():
	self.visible=false;
	var yes_button=$ExitPanel/YesButton;
	var no_button=$ExitPanel/NoButton;
	
	Events.show_panel_exit.connect(func() : self.visible=true);
	yes_button.pressed.connect(GameUtils.on_exit_game);
	no_button.pressed.connect(_on_exit_declined);

func _on_exit_declined():
	self.visible=false;
