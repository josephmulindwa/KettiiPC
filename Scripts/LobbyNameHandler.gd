extends Node

var input_field;
var warn_label;
var warn_panel;

func _ready():
	input_field=$NameFieldParent/NameField;
	warn_panel=$WarnPanel;
	warn_label=$WarnPanel/WarnLabel;
	
	input_field.text="Player"+str(randi_range(10, 99));
	MultiplayerConnectHandler.selfname=input_field.text;
	input_field.text_changed.connect(_on_text_changed);
	warn_panel.visible=false;
	warn_label.set_translate_key(0, "");
	
func _on_text_change_finished():
	# updates publicly available name
	var text=input_field.text;
	text=text.strip_edges(true, true);
	if (len(text)==0):
		warn_panel.visible=true;
		warn_label.set_translate_key(0, "T_INVALID_NAME");
		MultiplayerConnectHandler.selfname="";
		return;
	if (len(text)<Parameter.MIN_NAME_LENGTH):
		warn_panel.visible=true;
		warn_label.set_translate_key(0, "T_NAME_TOO_SHORT");
		MultiplayerConnectHandler.selfname=""
		return;
	MultiplayerConnectHandler.selfname=text;

func _on_text_changed():
	input_field.text=input_field.text.strip_edges(true, false);
	input_field.text=input_field.text.strip_escapes();
	input_field.text=CoreUtils.clean_string(input_field.text);
	input_field.text=input_field.text.left(Parameter.MAX_NAME_LENGTH);
	input_field.text=CoreUtils.first_char_to_upper(input_field.text);
	input_field.set_caret_column(len(input_field.text));
	warn_panel.visible=false;
	warn_label.set_translate_key(0, "");
	_on_text_change_finished();

