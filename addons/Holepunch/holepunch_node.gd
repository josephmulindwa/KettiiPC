extends Node

enum STATUS {
	CONNECT_FAILED, # failed to establish connection server
	CONNECT_SUCCESS, # successful connect
	CONTACT_FAILED, # failed to contact server
	GREET_STARTED,
	CONTACT_SUCCESS,
	CONFIRM_STARTED,
	GO_STARTED,
	CONNECT_STARTED, # started session register
	PEER_CONNECTED, # started session greet, received greet from peer
	SESSION_REGISTERED
};
#Signal is emitted when holepunch is complete. Connect this signal to your network manager
#Once your network manager received the signal they can host or join a game on the host port
signal hole_punched(my_port, hosts_port, hosts_address)

#This signal is emitted when the server has acknowledged your client registration, but before the
#address and port of the other client have arrived.
signal session_registered;
# signal to update network status externally
signal broadcast_status(status);

var server_udp = PacketPeerUDP.new()
var peer_udp = PacketPeerUDP.new()

#Set the rendevouz address to the IP address of your third party server
@export var rendevouz_address:String=""
#Set the rendevouz port to the port of your third party server
@export var rendevouz_port:int=4000
#This is the range of ports you will search if you hear no response from the first port tried
@export var port_cascade_range:int=10
#The amount of messages of the same type you will send before cascading or giving up
@export var response_window:int=16;

var found_server=false;
var recieved_peer_info=false;
var encoded_local_ips=null;

var is_host = false

var own_port
var peers={};
var peers_cache={};
var host_address = ""
var host_port = 0
var client_name
var p_timer
var session_id

var ports_tried = 0

const REGISTER_SESSION = "rs:"
const REGISTER_RANDOM = "rr:"
const REGISTER_CLIENT = "rc:"
const EXCHANGE_PEERS = "ep:"
const CHECKOUT_CLIENT = "cc:"
const PEER_GREET = "greet"
const PEER_CONFIRM = "confirm"
const PEER_GO = "go"
const SERVER_OK = "ok"
const SERVER_INFO = "peers"

var MAX_PLAYER_COUNT=GameDataManager.SAVEDATA.number_players;

# warning-ignore:unused_argument
func _process(delta):
	if peer_udp.get_available_packet_count() > 0:
		var array_bytes = peer_udp.get_packet()
		var packet_string = array_bytes.get_string_from_ascii()
		if packet_string.begins_with(PEER_GREET):
			var m = packet_string.split(":");
			if (m[1] in peers.keys()): # anti-cascade
				emit_signal('broadcast_status', STATUS.PEER_CONNECTED);
				_handle_greet_message(m[1], int(m[2]), int(m[3]));
		
		if packet_string.begins_with(PEER_CONFIRM):
			var m = packet_string.split(":");
			if (m[2] in peers.keys()):
				_handle_confirm_message(m[2], m[1], m[4], m[3])
		
		if packet_string.begins_with(PEER_GO):
			var m = packet_string.split(":");
			if (m[1] in peers.keys()):
				_handle_go_message(m[1])

	if server_udp.get_available_packet_count() > 0:
		var array_bytes = server_udp.get_packet()
		var packet_string = array_bytes.get_string_from_ascii()
		if packet_string.begins_with(SERVER_OK):
			var m = packet_string.split(":")
			if (m[1] in [REGISTER_CLIENT.left(2)]):
				host_address=m[1]+":"+m[2];
				own_port="-1";
				host_port="-1";
				_exit_procedure();
				return;
			else:
				own_port = int(m[1]);
				emit_signal('session_registered')
				emit_signal('broadcast_status', STATUS.SESSION_REGISTERED);
				if is_host:
					if !found_server:
						var msg=REGISTER_CLIENT+client_name+":"+session_id+":"+str(encoded_local_ips);
						_send_message_to_server(msg);
				found_server=true

		if not recieved_peer_info:
			if packet_string.begins_with(SERVER_INFO):
				server_udp.close()
				packet_string = packet_string.right(-6)
				if (packet_string.length() > 2):
					var client_peers=packet_string.split(",", false);
					if (client_peers.size()<1):
						# emit!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
						return;
					for pkt_string in client_peers:
						var m = pkt_string.split(":");
						if (len(m)<3):
							# emit!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
							return;
						# resolving addresses
						var address_string=m[1];
						var addresses=encodedstring_to_ips(address_string);
						if (randi_range(0, 3)==1): # add shuffle element, working address may be found faster
							addresses.shuffle();
							
						peers[m[0]] = {
								"port":m[2], 
								"address":addresses[0],
								"addresses":addresses,
								"confirms":{"sent":0, "received":0}, # semt_to_peer, rec_from_peer
								"greets":{"sent":0, "received":0},
								"gos":{"sent":0, "received":0},
								"address_itr":0 # marks what address is being used
							};
						recieved_peer_info = true;
						start_peer_contact();
					peers_cache=peers.duplicate(true);

func _handle_greet_message(peer_name, peer_port, my_port):
	if own_port != my_port:
		own_port = my_port
		peer_udp.close()
		peer_udp.bind(own_port, "*")
	if (peers[peer_name].greets.sent==0): # send greet before expecting one back
		return;
	peers[peer_name].greets.received+=1;

func _handle_confirm_message(peer_name, peer_port, my_port, peer_is_host):
	if (peers[peer_name].port!=peer_port):
		peers[peer_name].port = peer_port
	peers[peer_name].is_host = peer_is_host
	if (str(peer_is_host).to_lower()=="true"):
		host_address = peers[peer_name].address # watch address
		host_port = peers[peer_name].port
	peer_udp.close()
	peer_udp.bind(own_port, "*");
	if (peers[peer_name].confirms.sent==0): # send greet before expecting one back
		return;
	peers[peer_name].confirms.received+=1;

func _handle_go_message(peer_name):
	if (peers[peer_name].gos.sent==0):
		return;
	peers[peer_name].gos.received+=1;
	
	var received_all_gos=true;
	for p in peers.keys():
		received_all_gos=(received_all_gos && (peers[p].gos.received>0));
	if (received_all_gos):
		_exit_procedure();

func _exit_procedure():
	# steps to stop timer and process when connection is no longer needed
	emit_signal("hole_punched", int(own_port), int(host_port), host_address)
	peer_udp.close();
	p_timer.stop()
	set_process(false)

func _cascade_peer(add, peer_port):
	for i in range(peer_port - port_cascade_range, peer_port + port_cascade_range):
		peer_udp.set_dest_address(add, i)
		var buffer=PackedByteArray();
		buffer.append_array(("greet:"+client_name+":"+str(own_port)+":"+str(i)).to_utf8_buffer())
		peer_udp.put_packet(buffer)
		ports_tried += 1

func _ping_peer():
	"""
	sends handshakes to peer by
	sending signal if not yet sent or not received due to dropped/missed
	
	the function tests one address at a time; greets it, confirms and gos
	upon failure, it moves to the next address
	"""
	for p in peers.keys():
		var peer=peers[p];
		peers[p].address=peer.addresses[peer.address_itr];
		var address = peers[p].address;
		# if greet not sent to PEER or greet not yet rec from PEER
		if (peer.confirms.received==0):
			if (peer.greets.sent<response_window):
				peer_udp.set_dest_address(address, int(peers[p].port))
				var buffer=PackedByteArray();
				buffer.append_array(("greet:"+client_name+":"+str(own_port)+":"+peers[p].port).to_utf8_buffer())
				peer_udp.put_packet(buffer);
				emit_signal('broadcast_status', STATUS.GREET_STARTED);
			elif (peer.greets.sent==response_window):
				_cascade_peer(address, int(peers[p].port));
			peer.greets.sent+=1;		
		if (peer.greets.received && (peer.gos.received==0)):
			peer_udp.set_dest_address(address, int(peers[p].port))
			var buffer=PackedByteArray();
			buffer.append_array(("confirm:"+str(own_port)+":"+client_name+":"+str(is_host)+":"+peers[p].port).to_utf8_buffer())
			peer_udp.put_packet(buffer);
			if (peer.confirms.received==0):
				peer.confirms.sent+=1;
			emit_signal('broadcast_status', STATUS.CONFIRM_STARTED);
		if (peer.confirms.received>0):
			peer_udp.set_dest_address(address, int(peers[p].port))
			var buffer=PackedByteArray();
			buffer.append_array(("go:"+client_name).to_utf8_buffer())
			peer_udp.put_packet(buffer);
			emit_signal('broadcast_status', STATUS.GO_STARTED);
			peer.gos.sent+=1;
			
		await get_tree().create_timer(0.4).timeout;
			
		# ensure that look isn't indefinite 
		if (peer.greets.sent>response_window*1 || peer.confirms.sent>response_window*1):
			if (peer.address_itr>=(len(peer.addresses)-1)):
				emit_signal('broadcast_status', STATUS.CONNECT_FAILED);
				p_timer.stop();
				break;
			else:
				peers[p].address_itr+=1; # try another sent address
				peers[p].greets.sent=0;
				peers[p].confirms.sent=0;
	
	# since go's have no confirm, don't leave them open forever
	# if all go's are received OR one received but other exceeded OR all exceeded
	var go_state={}; # -v use a key-pair approach
	for p in peers.keys():
		if (peers[p].gos.sent>response_window):
			go_state[p]="exceeded";
		if (peers[p].gos.received>0):
			go_state[p]="received";
	
	#the other players have confirmed and are probably waiting
	if (len(go_state)==len(peers)):
		_exit_procedure();

func encodedstring_to_ips(enc_string):
	# converts the encoded string into the ips it represents
	var ips=[]
	var cache=[];
	while (len(enc_string)>0):
		var hexstring=enc_string.substr(0, CoreUtils.WORDSIZE);
		if (len(hexstring)<CoreUtils.WORDSIZE): # partial 
			break;
		cache.append(hexstring.hex_to_int());
		if (len(cache)==4):
			var c_ip=".".join(cache);
			if (c_ip not in ips):
				ips.append(c_ip);
			cache=[];
		enc_string=enc_string.substr(CoreUtils.WORDSIZE, -1);
	if (len(cache)==4):
		var c_ip=".".join(cache);
		if (c_ip not in ips):
			ips.append(c_ip);
	return ips;

func start_peer_contact():	
	server_udp.put_packet("goodbye".to_utf8_buffer())
	server_udp.close();
	if peer_udp.is_bound():
		peer_udp.close()
	var err = peer_udp.bind(own_port, "*")
	if err!=OK:
		#emit_signal('broadcast_status', STATUS.CONTACT_FAILED);
		pass;
	p_timer.start()
	emit_signal('broadcast_status', STATUS.CONTACT_SUCCESS);

#this function can be called to the server if you want to end the holepunch before the server closes the session
func finalize_peers(id):
	var buffer=PackedByteArray();
	buffer.append_array((EXCHANGE_PEERS+str(id)).to_utf8_buffer())
	server_udp.set_dest_address(rendevouz_address, rendevouz_port)
	server_udp.put_packet(buffer)

# remove a client from the server
func checkout():
	var buffer=PackedByteArray();
	if(client_name==null || CHECKOUT_CLIENT==null):
		return;
	buffer.append_array((CHECKOUT_CLIENT+client_name).to_utf8_buffer())
	server_udp.set_dest_address(rendevouz_address, rendevouz_port)
	server_udp.put_packet(buffer)

#Call this function when you want to start the holepunch process
func start_traversal(id, is_player_host, client_name_, is_random=false):
	if server_udp.is_bound(): # server listening
		server_udp.close();

	var err = server_udp.bind(rendevouz_port, "*");
	if (err!=OK):
		emit_signal('broadcast_status', STATUS.CONNECT_FAILED);
		return false;
	is_host = is_player_host
	client_name = client_name_;
	found_server = false
	recieved_peer_info = false
	
	peers = {}
	ports_tried = 0
	session_id = id
	
	emit_signal('broadcast_status', STATUS.CONNECT_SUCCESS);
	if (is_random):
		var msg=(REGISTER_RANDOM+session_id+":"+str(MAX_PLAYER_COUNT));
		return await _send_message_to_server(msg);
	
	if (is_host):
		var msg=(REGISTER_SESSION+session_id+":"+str(MAX_PLAYER_COUNT));
		return await _send_message_to_server(msg);
	else:
		var msg=REGISTER_CLIENT+client_name+":"+session_id+":"+str(encoded_local_ips);
		return await _send_message_to_server(msg);
	return true;

func _send_message_to_server(msg:String):
	await get_tree().create_timer(2.0).timeout;
	var buffer=PackedByteArray();
	buffer.append_array((msg).to_utf8_buffer())
	server_udp.close()
	var err=server_udp.set_dest_address(rendevouz_address, rendevouz_port);
	if(err!=OK):
		emit_signal('broadcast_status', STATUS.CONTACT_FAILED);
		return false;
	err=server_udp.put_packet(buffer);
	if (err!=OK):
		emit_signal('broadcast_status', STATUS.CONTACT_FAILED);
		return false;
	emit_signal('broadcast_status', STATUS.CONTACT_SUCCESS);
	return true;

func _exit_tree():
	server_udp.close()

func _ready():
	p_timer = Timer.new();
	get_node("/root/").call_deferred("add_child", p_timer);
	p_timer.timeout.connect(_ping_peer);
	p_timer.wait_time=0.1;
	
	# register addresses
	encoded_local_ips="";
	for address in IP.get_local_addresses():
		var components=address.split('.');
		if (components.size()==4):
			if (int(components[0])==127 && int(components[3])==1):
				continue;
			for n in components:
				encoded_local_ips+=CoreUtils.to_hex(int(n));
	
