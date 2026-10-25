extends Node
# Networking (autoload "Net"): hosts a server or joins one, and carries the
# settings the boot menu picked over to the world scene.

const Config := preload("res://game/common/config.gd")
const Races := preload("res://game/common/races.gd")

signal joined
signal join_failed(reason: String)

enum Mode { CLIENT, HOST, DEDICATED }

# Filled in by the boot menu or the command line before the world loads.
var mode := Mode.CLIENT
var address := "127.0.0.1"
var port := Config.DEFAULT_PORT
var zone := Config.DEFAULT_ZONE
var profile := {"name": "Player", "race": 0, "sex": 0}
var smoke_seconds := 0.0   # > 0: automated test run, quit after this long
var smoke_expect := 1       # test passes once this many players are visible

var world: Node = null
var spawned_count := 0


func is_server() -> bool:
	return mode != Mode.CLIENT


func start_server() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[server] listening on port %d" % port)
	return OK


func join() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): joined.emit(), CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(func(): join_failed.emit("Could not reach the server"), CONNECT_ONE_SHOT)
	multiplayer.server_disconnected.connect(func(): join_failed.emit("Lost connection to the server"), CONNECT_ONE_SHOT)
	print("[client] connecting to %s:%d" % [address, port])
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	world = null


# Client -> server: "put my character in the world".
@rpc("any_peer", "call_remote", "reliable")
func request_spawn(p: Dictionary) -> void:
	if not is_server() or world == null:
		return
	world.spawn_player(multiplayer.get_remote_sender_id(), Races.sanitize(p))


func _on_peer_disconnected(id: int) -> void:
	print("[server] player %d left" % id)
	if world:
		world.despawn_player(id)
