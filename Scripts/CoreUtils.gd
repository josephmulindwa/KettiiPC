extends Node

var WORDSIZE=2;
var ENCODEFORMAT:String="%0"+str(WORDSIZE)+"X"; # %02X
var PATTERN_ALNUM_SPACE:String="^[A-Za-z0-9 ]+$";

func to_radians(angle:float)->float:
	return PI*angle/180.0;

func get_x(angle:float, d:float)->float:
	# gives x given angle and distance
	return d*cos(to_radians(angle));

func get_y(angle:float, d:float)->float:
	# gives y given angle and distance
	return d*sin(to_radians(angle));

func get_angular_position(angle:float, distance:float, origin:Vector2)->Vector2:
	# returns Point based on angle and distance
	var x = origin.x + get_x(angle, distance);
	var y = origin.y + get_y(angle, distance);
	return Vector2(x, y);

func get_reflection_vector(vs:Vector2, vw:Vector2):
	# returns the reflection vector given the speed vector vs and wall vector vw
	var ax = (vs.x*vw.x+vs.y*vw.y)*vw.x;
	var ay = (vs.x*vw.x+vs.y*vw.y)*vw.y;
	var arx = 2*ax-vs.x;
	var ary = 2*ay-vs.y;
	return Vector2(arx, ary);

func normalize_vector(v:Vector2):
	var magnitude=pow(v.x*v.x+v.y*v.y, 0.5);
	if (magnitude==0):
		return Vector2(0.01, 0.01); # erroneous
	return Vector2(v.x/magnitude, v.y/magnitude);

func get_perpendicular_vector(v:Vector2):
	return Vector2(-v.y, v.x);

func get_fill_distribution_values(n:int)->Array[int]:
	# calculates number of pieces put on tile
	var lenn=2; #MAX_PIECES;
	var x=1; var y=1; var dy=1;
	for i in range(1, lenn+1):
		if (x*y>=n):
			break;
		if (dy==1):
			dy=0;
			y+=1;
		else:
			dy=1;
			x+=1;
	return [x, y];

func to_hex(i:int)->String:
	return ENCODEFORMAT%(i)

func array_to_encoded_string(arr:Array)->String:
	"""
	encodes an array in the following form
	len,index_of_max[e.g if iom=2] => diff, diff, max, diff 
	where diff=max-arr[i]
	00 03 01 02 -> 04 01 03 03 02 01
	"""
	if (len(arr)==0):
		return ""
	var max_idx:int=0
	var max_value:int=arr[max_idx];
	for i in range(1,len(arr)):
		if (arr[i]>max_value):
			max_value=arr[i];
			max_idx=i;
	var s="";
	s+=to_hex(len(arr));
	s+=to_hex(max_idx);
	var diff:int;
	for i in range(len(arr)):
		diff=arr[i];
		if (i!=max_idx):
			diff=max_value-arr[i];
		s+=to_hex(diff);
	return s

func encoded_string_to_array(s:String)->Array:
	"""
	takes a hex string stack and generates the array it represents 
	as a reverse of `array_to_encoded_string`
	"""
	var start_index:int=0;
	if (len(s)<(start_index+WORDSIZE)):
		return []
	var temp:String = s.substr(start_index, WORDSIZE);
	var length:int=temp.hex_to_int();
	start_index+=WORDSIZE;
	if (len(s)<(start_index+WORDSIZE)):
		return []
	temp=s.substr(start_index, WORDSIZE)
	var max_idx:int=temp.hex_to_int();
	start_index+=WORDSIZE;
	if (len(s)<(start_index+WORDSIZE)):
		return [];
	var tmp_arr:Array=create_array_1d(length);
	var arr=[]
	for i in range(length):
		temp=s.substr(start_index, WORDSIZE);
		if (len(s)<(start_index+WORDSIZE)):
			return [];
		start_index+=WORDSIZE;
		tmp_arr[i]=temp.hex_to_int();
	# array
	for i in range(length):
		if(i>=len(tmp_arr) || max_idx>=len(tmp_arr)):
			return [];
		var val=tmp_arr[i];
		if (i!=max_idx):
			val=tmp_arr[max_idx]-tmp_arr[i];
		arr.append(val);
	return arr;
	
func create_array_1d(length:int, default_value=0):
	var col = [];
	col.resize(length);
	for i in range(length):
		col[i]=default_value;
	return col;
	
func create_array_2d(nrows:int, ncols:int, default_value=0):
	var arr:Array[Array]=[];
	for i in range(nrows):
		var row = create_array_1d(ncols, default_value);
		arr.append(row);
	return arr;

func array_ravel_2d(arr_2d):
	# returns linear array of 2d
	var arr:Array=[];
	for i in range(len(arr_2d)):
		for j in range(len(arr_2d[i])):
			arr.append(arr_2d[i][j]);
	return arr;

func sort_for_miny_maxx(a:Vector2, b:Vector2):
	# sorts vectors putting by (miny, maxx); smallest y, highest x
	if (a.y!=b.y):
		return (a.y<b.y);
	return (a.x>b.x);
	
func is_clean_string(s, pattern=PATTERN_ALNUM_SPACE):
	"""checks that string contains letters numbers and space only"""
	var regex=RegEx.new();
	regex.compile(pattern);
	var result=regex.search(s);
	return (result!=null);

func clean_string(s, pattern=PATTERN_ALNUM_SPACE):
	# returns a string cleaned by pattern
	var result="";
	for i in range(len(s)):
		var c=s[i];
		if (is_clean_string(c, pattern)):
			result+=c;
	return result;

func first_letter_to_upper(s:String):
	# capitalizes first letter found only
	if (len(s)==0):
		return s;
	s=s.to_lower();
	var result="";
	var raised=false;
	for chr in s:
		if (!raised):
			var upper=chr.to_upper();
			if (upper!=chr):
				result+=upper;
				raised=true;
				continue;
		result+=chr;
	return result;

func first_char_to_upper(s:String):
	# raises the first character 
	if (len(s)==0):
		return s;
	return s[0].to_upper()+s.substr(1);
