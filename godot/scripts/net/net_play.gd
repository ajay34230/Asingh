## Play with friends on the same Wi-Fi.
##
## One phone hosts (ENet server); friends join by tapping the host in the list (found
## by a UDP broadcast) or by typing its address. The host is the authority: it rolls
## every dice and chooses every AI move, then sends each action to all phones. Every
## phone runs the same rules engine on the same actions in the same order, so all
## boards stay identical. Actions wait in a queue until the local animations finish,
## so a slower phone never falls out of step.
class_name NetPlay
extends Node

signal lobby_changed(players: Array)       ## [{id, name}]
signal hosts_found(hosts: Array)           ## [{name, ip, port}]
signal game_started(config: Dictionary)
signal disconnected(reason: String)

const PORT := 7790
const DISCOVERY_PORT := 7791
const MAX_CLIENTS := 3

var game: GameController
var active := false            ## a network game is running
var is_host := false
var owners := {}               ## colour -> peer id (1 = host); AI colours are absent
var _players: Array = []       ## lobby, host first
var _queue: Array = []         ## pending actions: ["roll", value] / ["pick", colour, index]
var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_time := 0.0
var _hosts := {}               ## ip -> {name, ip, port, seen}
var my_name := "Player"


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: _register.rpc_id(1, my_name))
	multiplayer.connection_failed.connect(func() -> void: disconnected.emit("Could not connect"))
	multiplayer.server_disconnected.connect(func() -> void:
		active = false
		disconnected.emit("The host left the game"))


# --- hosting and joining -----------------------------------------------------------

func host(player_name: String) -> Error:
	leave()
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	_players = [{"id": 1, "name": my_name}]
	lobby_changed.emit(_players)
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	return OK


func join(address: String, player_name: String) -> Error:
	leave()
	my_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	_players.clear()
	_queue.clear()
	owners.clear()
	if _beacon:
		_beacon.close()
		_beacon = null


## Starts listening for hosts on the local network.
func discover(on: bool) -> void:
	if on and _listener == null:
		_listener = PacketPeerUDP.new()
		if _listener.bind(DISCOVERY_PORT) != OK:
			_listener = null
	elif not on and _listener:
		_listener.close()
		_listener = null
		_hosts.clear()


## This phone's local network address, for friends to type in.
static func local_address() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			return a
	return "?"


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	_players.append({"id": id, "name": String(player_name).substr(0, 16)})
	_sync_lobby.rpc(_players)
	lobby_changed.emit(_players)


@rpc("authority", "reliable")
func _sync_lobby(players: Array) -> void:
	_players = players
	lobby_changed.emit(_players)


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	_players = _players.filter(func(p: Dictionary) -> bool: return int(p["id"]) != id)
	if is_host:
		_sync_lobby.rpc(_players)
		## A player who leaves mid-game is replaced by the computer.
		for c in owners.keys():
			if int(owners[c]) == id:
				owners.erase(c)
				_set_owners.rpc(owners)
	lobby_changed.emit(_players)


@rpc("authority", "reliable", "call_local")
func _set_owners(o: Dictionary) -> void:
	owners = o
	if game and game.engine:
		for seat in game.engine.seats:
			seat["human"] = owners.has(seat["color"])


# --- starting a game ---------------------------------------------------------------

## Host only: seats everyone (host blue, then yellow, green, red); empty seats are AI.
func start(difficulty: int, rules: Dictionary, seats := 4) -> void:
	if not is_host:
		return
	var colors := ["blue", "yellow", "green", "red"].slice(0, maxi(2, seats))
	if seats == 2:
		colors = ["blue", "green"]
	var o := {}
	for i in range(mini(_players.size(), colors.size())):
		o[colors[i]] = int(_players[i]["id"])
	var config := {"colors": colors, "owners": o, "seed": randi() % 1000000 + 1, "difficulty": difficulty, "rules": rules}
	_begin.rpc(config)


@rpc("authority", "reliable", "call_local")
func _begin(config: Dictionary) -> void:
	owners = config["owners"]
	active = true
	_queue.clear()
	if _beacon:
		_beacon.close()
		_beacon = null
	game_started.emit(config)


func is_local(color: String) -> bool:
	return active and int(owners.get(color, -1)) == multiplayer.get_unique_id()


func is_ai(color: String) -> bool:
	return active and not owners.has(color)


# --- actions -------------------------------------------------------------------------

## A local player tapped the dice.
func request_roll() -> void:
	if is_host:
		_host_roll(1)
	else:
		_ask_roll.rpc_id(1)


@rpc("any_peer", "reliable")
func _ask_roll() -> void:
	_host_roll(multiplayer.get_remote_sender_id())


func _host_roll(sender: int) -> void:
	var color := game.current_color()
	if int(owners.get(color, 1 if is_ai(color) else -1)) != sender and not (is_ai(color) and sender == 1):
		return
	_do.rpc(["roll", randi_range(1, 6)])


func request_pick(color: String, index: int) -> void:
	if is_host:
		_host_pick(1, color, index)
	else:
		_ask_pick.rpc_id(1, color, index)


@rpc("any_peer", "reliable")
func _ask_pick(color: String, index: int) -> void:
	_host_pick(multiplayer.get_remote_sender_id(), color, index)


func _host_pick(sender: int, color: String, index: int) -> void:
	if int(owners.get(color, 1 if is_ai(color) else -1)) != sender and not (is_ai(color) and sender == 1):
		return
	_do.rpc(["pick", color, index])


## Host only: the computer plays a seat.
func ai_roll() -> void:
	if is_host:
		_do.rpc(["roll", randi_range(1, 6)])


func ai_pick(index: int) -> void:
	if is_host:
		_do.rpc(["pick", game.current_color(), index])


@rpc("authority", "reliable", "call_local")
func _do(action: Array) -> void:
	_queue.append(action)


func _process(delta: float) -> void:
	## Host beacon: "ROYALLUDO|name|players" once a second while the lobby is open.
	if _beacon and not active:
		_beacon_time -= delta
		if _beacon_time <= 0.0:
			_beacon_time = 1.0
			_beacon.put_packet(("ROYALLUDO|%s|%d" % [my_name, _players.size()]).to_utf8_buffer())
	if _listener:
		var changed := false
		while _listener.get_available_packet_count() > 0:
			var text := _listener.get_packet().get_string_from_utf8()
			var ip := _listener.get_packet_ip()
			var parts := text.split("|")
			if parts.size() >= 3 and parts[0] == "ROYALLUDO":
				changed = changed or not _hosts.has(ip)
				_hosts[ip] = {"name": parts[1], "players": int(parts[2]), "ip": ip, "seen": Time.get_ticks_msec()}
		for ip in _hosts.keys():
			if Time.get_ticks_msec() - int(_hosts[ip]["seen"]) > 4000:
				_hosts.erase(ip)
				changed = true
		if changed:
			hosts_found.emit(_hosts.values())
	## Apply queued actions once this phone is ready for them.
	if active and game and not _queue.is_empty() and not game.busy:
		var a: Array = _queue[0]
		if a[0] == "roll" and game.engine.phase == RulesEngine.PHASE_ROLL:
			_queue.pop_front()
			game.forced_roll = int(a[1])
			game._roll_now()
		elif a[0] == "pick" and game.engine.phase == RulesEngine.PHASE_MOVE and game.current_color() == a[1]:
			_queue.pop_front()
			game.net_execute(int(a[2]))
