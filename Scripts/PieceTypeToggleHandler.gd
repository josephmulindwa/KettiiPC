extends Node

var tick_circle_sprite;
var null_circle_sprite;
var selectable_button_list=[];
var selectable_pad_list=[];
var toggle_handler;

func _input(event):
	if(!self.visible):
		return;
	var mouse_click = event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT;
	if (event is InputEventScreenTouch || mouse_click):
		var rect;
		for i in range(len(self.selectable_pad_list)):
			var pad_selectable=self.selectable_pad_list[i];
			var btn_selectable=self.selectable_button_list[i];
			rect = Rect2(Vector2(0, 0), pad_selectable.size);
			if (rect.has_point(pad_selectable.get_local_mouse_position())):
				toggle_handler.toggle_index(i);
				break;
			rect = Rect2(Vector2(0, 0), btn_selectable.size); 
			if (rect.has_point(btn_selectable.get_local_mouse_position())):
				toggle_handler.toggle_index(i);
				break;

func _ready():
	self.visible=false;
	var close_button=$PieceTypePanel/CloseButton;
	
	toggle_handler=GameDataManager.ASSETS["toggle_manager"].new();
	add_child(toggle_handler);
	tick_circle_sprite=GameDataManager.ASSETS["circle_x_tick"];
	null_circle_sprite=GameDataManager.ASSETS["circle_x_null"];
		
	selectable_button_list=[
		$PieceTypePanel/RimRect/PositionControl/ButtonSelectable, 
		$PieceTypePanel/ConeRect/PositionControl/ButtonSelectable
	];
	selectable_pad_list=[$PieceTypePanel/RimRect, $PieceTypePanel/ConeRect];
	
	toggle_handler.item_list=selectable_pad_list;
	toggle_handler.enabled_callback=self.on_enabled;
	toggle_handler.disabled_callback=self.on_disabled;
	
	if (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.CONE):
		toggle_handler.toggle_index(1);
	elif (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.RIM):
		toggle_handler.toggle_index(0);
	
	Events.show_panel_piece_type.connect(
		func():
			Parameter.PANEL_ACTIVE=true;
			self.visible=true;
	);
	Events.trigger_close_panel.connect(_on_close_button_pressed);
	close_button.pressed.connect(_on_close_button_pressed);
	self.tree_exiting.connect(
		func() : GameUtils.free_items([toggle_handler]);
	);
	
func on_enabled(item):
	var btn_selectable=item.get_node("PositionControl/ButtonSelectable");
	var round_rect=item.get_node("RoundRect");
	round_rect.visible=true;
	btn_selectable.texture=tick_circle_sprite;
	btn_selectable.size=Vector2(72.0, 72.0);
	btn_selectable.position=-(btn_selectable.size/2.0);
	item.modulate=Color(1.0, 1.0, 1.0);
	item.scale=Vector2(1.0, 1.0);
	var piece_types=[Parameter.PIECE_TYPE.RIM, Parameter.PIECE_TYPE.CONE];
	for i in range(len(toggle_handler.item_list)):
		if (item==toggle_handler.item_list[i]):
			GameDataManager.CONFIGDATA.set_piece_type(piece_types[i]);
			break;
	
func on_disabled(item):
	var btn_selectable=item.get_node("PositionControl/ButtonSelectable");
	var round_rect=item.get_node("RoundRect");
	round_rect.visible=false;
	btn_selectable.texture=null_circle_sprite;
	btn_selectable.size=Vector2(36.0, 36.0);
	btn_selectable.position=-(btn_selectable.size/2.5);
	item.modulate=Color(0.7, 0.7, 0.7);
	item.scale=Vector2(0.85, 0.85);

func _on_close_button_pressed():
	Parameter.PANEL_ACTIVE=false;
	Events.emit_signal("panel_piece_type_closed");
	self.visible=false;
