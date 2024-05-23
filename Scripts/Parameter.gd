extends Node;

"""container for default data and data accessed by more than one scene"""

var TUTORIALS_LINK="https://www.youtube.com/playlist?list=PLu3k_6Bw6bciLG3MK3viHqTpCwU24Nm3x";

var  VERSION_NUMBER = "1.04"; # accessed at Exports>version
enum PLAYER_TYPE {NONE, CPU, HUMAN, WEB};
enum PIECE_TYPE {RIM, CONE};
enum AI_MODE {SIMPLE, SMART};
enum GAME_MODE {CPU, TABLE, ONLINE};
enum CONNECTION_STATE {CONNECTED, DISCONNECTED};
enum LANGUAGE {EN, FR, HI, IT, SP, JP, AR, PT}; # English, French, Hindi, Italian, Spanish, Japanese

var MIN_PLAYERS=2;
var MAX_SECTORS=3;
var MAX_PLAYERS=4;
var MAX_PIECES=3;
var MAX_DIVISIONS=40;
var MAX_DIE=2;
var MIN_NAME_LENGTH=3;
var MAX_NAME_LENGTH=11;
var BOARD_SHIFT=6;
var BACK_STEPS=MAX_DIVISIONS;
var YARD_LOCATION=0;
var CYCLE_TIMER_OBJECT=null;
var ROLLS=CoreUtils.create_array_1d(MAX_DIE);
var HOME_LOCATION=1+(MAX_SECTORS*MAX_DIVISIONS)+1;

var STANDARD_TILE_SIZE=40.0;
var STANDARD_RIM_RATIO=1.5;
var PIECE_SIZE=Vector2(STANDARD_TILE_SIZE, STANDARD_TILE_SIZE*STANDARD_RIM_RATIO); # the default piece size
var PIECE_OVERLAP_RATIO=0.55;
var PIECE_OVERLAP_RATIOS_CONSTANT:Array[Vector2];
var PLAYER_COLORS:Array[Color] = [Color(1, 0, 0, 1), Color(0, 0.63, 1, 1), Color(1, 0.9, 0, 1), Color(0, 1, 0, 1)];
var PLAYER_ENABLE_STATES:Array=[[false, true, false, true], [false, true, true, true], [true, true, true, true]];
var LOCK_COLLISION=false; # locks collision ~when loading game
var DEFAULT_MOVE_STEP_TIME : float = 0.2;
var MAX_SPINRATE:float=100;

# general control parameters
var GAME_PAUSED=false;
var GAME_READY=false;
var GAME_COMPLETED=false;
var SELF_COMPLETED=false;
var PLACING_PIECE=false;
var EXITED_BY_AD=false;
var FULL_SCREEN_AD_RUNNING=false; # indicates full screen ad showing
var PANEL_ACTIVE=false; # indicates (any) panel being active; used by back button
var SELF_PLAYER_ID:int=0; #id of player chosen to play as

# gamescene fillables
var PLAYER_NAMES:Array;
var PLAYER_TYPES:Array;
var PLAYER_CONNECTION_STATES:Array;
var CURRENT_PLAYER_ID;
var PLAYER_COMPLETION_PERCENTAGES:Array;
var PLAYER_COMPLETION_STATES:Array;
var RIM_PIECE_PREFABS:Array; 
var CONE_PIECE_PREFABS:Array;
var STATE_HANDLER=null;

# PLAY CYCLE
var STATE=null;

func reset_game_state():
	GAME_PAUSED=false;
	GAME_READY=false;
	GAME_COMPLETED=false;
	SELF_COMPLETED=false;
	PLACING_PIECE=false;
	
	PLAYER_NAMES=[];
	PLAYER_TYPES=[];
	PLAYER_CONNECTION_STATES=[];
	PLAYER_COMPLETION_PERCENTAGES=[];
	PLAYER_COMPLETION_STATES=[];
	RIM_PIECE_PREFABS=[]; 
	CONE_PIECE_PREFABS=[];

func reset_cycle():
	STATE={
		"ROLLS_USED":CoreUtils.create_array_1d(MAX_DIE, false),
		"MOVING_PIECE_ID":-1,
		"MOVING_PLAYER_ID":-1,
		"SELECTED_PAD_ID":-1,
		"STATE":0
	};
	if (STATE_HANDLER!=null):
		STATE_HANDLER.reset();
