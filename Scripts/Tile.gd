extends Control

class_name Tile
## represents a quick-interact tile object
var sector:int=-1;
var pieces:Array=[];
var non_color_piece;
var inner=null;
var node2d=null;

func _ready():
	inner=$Tile;
	node2d=$Tile/Node2D;

func _to_string()->String:
	return "Tile(name="+self.name+", numberPieces="+str(len(self.pieces))+")";

func _set_up_piece_parent(piece:Piece):
	if (piece.tile_parent!=null):
		piece.tile_parent.remove_piece(piece);
	inner.add_child(piece);
	piece.tile_parent=self;
	piece.rotation_degrees=-self.rotation_degrees;

func add_piece(piece:Piece):
	for i in range(len(self.pieces)):
		if (self.pieces[i]!=null && self.pieces[i].name==piece.name):
			return;
	_set_up_piece_parent(piece);
	self.pieces.append(piece);
	_on_piece_number_changed();

func remove_piece(piece:Piece):
	var index:int=-1;
	for i in range(len(pieces)):
		if(self.pieces[i]!=null && self.pieces[i].name==piece.name):
			index=i;
			break;
	if (index==-1):
		return;
	# start after effect
	if(Parameter.STATE_HANDLER.check_if_state_is("MOVING")):
		piece.start_after_effect();
	# remove element
	inner.remove_child(self.pieces[index]);
	self.pieces.remove_at(index);
	_on_piece_number_changed();

func _on_piece_number_changed():
	place_pieces_on_tile();

func place_pieces_on_tile():
	# place pieces on tile with an overlap
	var overlap_ratios:Array=[0.1,0.3,0.5,0.5]; # piece overlap ratio
	var sector_maximums:Array=[4, 4, 2, 2];
	var tile_dividends:Array=[[1,1],[2,2],[2,2],[2,2]]; # how many dividends to make
	var tile_placements:Array=[[1],[1,0,0,1],[1,1,1,0],[1,1,1,1]]; # how to place pieces
	
	Parameter.PLACING_PIECE=true;
	var number_pieces = len(self.pieces);
	if(number_pieces==0):
		return;
	var number_drawable_pieces=min(number_pieces, sector_maximums[self.sector]);
	var tile_divide=tile_dividends[number_drawable_pieces-1];
	var tile_placement=tile_placements[number_drawable_pieces-1];
	var _overlap_ratio=0.0;
	if (self.sector>=0 && number_drawable_pieces>1):
		_overlap_ratio=overlap_ratios[self.sector];
	
	# set up cone zoom
	var zoom=1.0;
	if (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.CONE):
		zoom=1.2;
	
	var nx=tile_divide[0]; var ny=tile_divide[1];
	# calculate the size of the piece that will be drawn wholly;
	var tile_size=$Tile.size;
	var div_x_size:float=tile_size.x/nx;
	var div_y_size:float=tile_size.y/ny;
	var det_piece_size:float = min(Parameter.PIECE_SIZE.x*zoom, Parameter.PIECE_SIZE.y*zoom);
	var div_size:float=min(div_x_size, div_y_size, det_piece_size);
	var scaling_factor:float=div_size/det_piece_size;
	var drawable_size:Vector2=Parameter.PIECE_SIZE*zoom*scaling_factor*(1+_overlap_ratio);
	# get positions
	var new_positions=[];
	var position_struct:Array=[];
	var center_ratio=0.5+(0.5*_overlap_ratio);
	var cx:float=(tile_size.x*center_ratio)/nx; # overlap can be controlled here
	var addend_x=(1-center_ratio)*tile_size.x;
	var addend_y=(1-center_ratio)*tile_size.y;
	var k:int=0;
	for i in range(nx):
		var cy:float=(tile_size.y*center_ratio)/ny;
		for j in range(ny):
			if (tile_placement[k]==1):
				new_positions.append(Vector2(cx, cy));
			k+=1;
			cy+=addend_y;
		cx+=addend_x;
	
	for i in range(len(new_positions)):
		var global_pos=node2d.to_global(new_positions[i]);
		position_struct.append([global_pos, i]);
		
	# sort positions to start from down
	position_struct.sort_custom(func(a, b): return CoreUtils.sort_for_miny_maxx(a[0], b[0]));
	
	# internally re-order so that .player_id pieces are on top
	# fill current_player_indices from front and other players from back
	var reordered_indices:Array=CoreUtils.create_array_1d(number_pieces, -1);
	var l=0; var r=number_pieces-1; 
	for i in range(number_pieces):
		if (self.pieces[i].player_id==Parameter.CURRENT_PLAYER_ID):
			reordered_indices[l]=i;
			l+=1;
		else:
			reordered_indices[r]=i;
			r-=1;
	
	# draw pieces
	var itr=0;
	var ritr;
	# remove noncolor
	if (non_color_piece!=null):
		if (non_color_piece.get_parent()!=null):
			non_color_piece.get_parent().remove_child(non_color_piece);
		non_color_piece.queue_free();
		non_color_piece=null;
	
	# make pieces invisible
	for i in range(number_pieces):
		self.pieces[i].visible=false;
	
	while (itr<number_drawable_pieces):
		ritr=number_drawable_pieces-itr-1;
		var piece_idx=reordered_indices[ritr];
		var pos_idx=position_struct[itr][1];
		var drawable_piece=self.pieces[piece_idx];
		# add non-color
		if (itr==0 && number_pieces>number_drawable_pieces):
			if (non_color_piece==null):
				var _prefab=null;
				if (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.RIM):
					_prefab=Parameter.RIM_PIECE_PREFABS[Parameter.MAX_PLAYERS];
				elif (GameDataManager.CONFIGDATA.piece_type==Parameter.PIECE_TYPE.CONE):
					_prefab=Parameter.CONE_PIECE_PREFABS[Parameter.MAX_PLAYERS];
				non_color_piece=_prefab.instantiate();
				_set_up_piece_parent(non_color_piece);
				non_color_piece.modulate=Color(0,0,0);
			drawable_piece=non_color_piece;
		drawable_piece.set_piece_size(drawable_size);
		drawable_piece.position=new_positions[pos_idx];
		drawable_piece.visible=true;
		inner.move_child(drawable_piece, -1);
		itr+=1;
	Parameter.PLACING_PIECE=false;

func get_colliding_piece(piece:Piece, is_forward_pass=true):
	# checks which pieces on the tile collide with this piece and are removable
	var colliding_piece=null;
	if (len(self.pieces)<=1 || len(self.pieces)>2):
		return null;
	# check the other piece
	for i in range(len(self.pieces)):
		if (piece.player_id!=self.pieces[i].player_id):
			if (is_forward_pass):
				colliding_piece=self.pieces[i];
			else:
				colliding_piece=piece;
			break;
	return colliding_piece;

func _process(_delta):
	if(Parameter.STATE_HANDLER.check_if_state_is("START_CYCLE")): # anti-flicker on_table
		return;
	var board_flipped=(GameDataManager.SAVEDATA.active_game_mode in [Parameter.GAME_MODE.CPU, Parameter.GAME_MODE.ONLINE] && Parameter.SELF_PLAYER_ID>=(Parameter.MAX_PLAYERS/2.0));
	if (board_flipped):
		if (inner.rotation_degrees!=180.0):
			inner.rotation_degrees=180.0;
			GameDataManager.CONFIGDATA.piece_type_changed=true;
	else:
		if(inner.rotation_degrees!=0.0):
			inner.rotation_degrees=0.0;
			GameDataManager.CONFIGDATA.piece_type_changed=true;
