extends Label

class_name TranslateHandler;

"""
adapts to the label it is attached to and adjusts its .text element to the selected language
"""
@export var translate_keys:Array[String]; # list of words to translate by their keys
@export var bind_list:Array[String]; # list of characters that bind/join translate keys
@export var enumeration_bind:String; # the string that will replace the enum
@export var font_size_ratios:Dictionary;
@export var display_format:String="CAMEL";

enum  DISPLAY_FORMAT {CAMEL, LOWER, UPPER, SENTENCE, CAMELF}; # text display format
var default_label_settings;
var translate_language=null; # the language to translate to for self
var auto_update:bool=true; # whether to auto update from configdata
var translate_element_changed=false;

func _ready():
	self.text="";
	if (translate_keys==null || len(translate_keys)==0):
		translate_keys=[];
	if (bind_list==null || len(bind_list)==0):
		bind_list=[];
	if (display_format not in DISPLAY_FORMAT.keys()):
		display_format="CAMEL";
	default_label_settings=label_settings;
	if (translate_language==null):
		self.translate_language=GameDataManager.CONFIGDATA.language;
	_render_text();

func get_translated_text():
	# combines translate_keys to form a word;
	var result="";
	for i in range(len(translate_keys)):
		var pkey=translate_keys[i];
		var translated=GameUtils.get_translated(pkey, translate_language, enumeration_bind);
		if (translated==null): # translate failed
			translated=pkey;
		result+=translated;
		if (i<len(bind_list)):
			result+=bind_list[i];
	if (display_format=="LOWER"): # all characters to lower
		result=result.to_lower();
	elif (display_format=="UPPER"): # all characters to upper
		result=result.to_upper();
	elif (display_format=="CAMEL"): # all first letter of each word to upper
		var splits=result.split(" ");
		var res_array=[];
		for word in splits:
			res_array.append(CoreUtils.first_letter_to_upper(word));
		result=" ".join(res_array);
	elif (display_format=="SENTENCE"): # first letter of entire phrase to upper
		var splits=result.split(" ");
		var res_array=[];
		for i in range(len(splits)):
			var s=splits[i];
			if (i==0):
				s=CoreUtils.first_letter_to_upper(s);
			res_array.append(s)
		result=" ".join(res_array);
	elif (display_format=="CAMELF"): # first char of each word to upper
		var splits=result.split(" ");
		var res_array=[];
		for word in splits:
			res_array.append(CoreUtils.first_char_to_upper(word));
		result=" ".join(res_array);
	return result;

func set_enumeration_bind(value:String):
	self.enumeration_bind=value;
	self.translate_element_changed=true;

func set_translate_key(index:int, value:String):
	"""
	sets the translate index to a value
	allows you to add text that blends with translated text
	"""
	if (index>=len(translate_keys)):
		var diff=(len(translate_keys)-index)+1;
		for i in range(diff):
			translate_keys.append("");
	if (translate_keys[index]!=value):
		translate_keys[index]=value;
		self.translate_element_changed=true;

func set_translate_keys(keys):
	if (keys!=self.translate_keys):
		self.translate_keys=keys;
		self.translate_element_changed=true;

func set_translate_language(_language):
	# sets translate language for this object
	self.translate_language=_language;
	self.auto_update=false;
	self.translate_element_changed=true;

func get_font_size_ratio():
	# returns font_ration for current translate language
	var language_key=Parameter.LANGUAGE.keys()[translate_language];
	if (language_key!=null && font_size_ratios!=null):
		if (language_key in font_size_ratios.keys()):
			return font_size_ratios[language_key];
	return 1.0;

func _render_text():
	self.text=get_translated_text();
	# setting font size
	var ls=default_label_settings.duplicate();
	ls.font_size=(ls.font_size*get_font_size_ratio());
	label_settings=ls;

func _process(_delta):
	self.translate_element_changed=(self.translate_element_changed || self.translate_language!=GameDataManager.CONFIGDATA.language);
	if (self.translate_element_changed):
		if (auto_update):
			self.translate_language=GameDataManager.CONFIGDATA.language;
		_render_text();
		self.translate_element_changed=false;
