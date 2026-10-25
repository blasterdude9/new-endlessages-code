extends Node3D
# The game world: loads an EA-Godot zone, starts or joins the server, and
# spawns players. The server decides who exists; the MultiplayerSpawner
# copies every spawned player to all clients.

const Config := preload("res://game/common/config.gd")
const PLAYER_SCENE := preload("res://game/player/player.tscn")

@onready var zone_holder: Node3D = $Zone
@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var status: Label = $HUD/Status

var spawn_point := Vector3.ZERO
var _seen := {}   # every player that has been in the world (used by the smoke test)
var _u := Config.UNITS_PER_METER


func _ready() -> void:
	Net.world = self
	spawner.spawn_function = _make_player
	players.child_entered_tree.connect(func(n): _seen[n.name] = true)
	_load_zone(Net.zone)

	if Net.smoke_seconds > 0.0:
		get_tree().create_timer(Net.smoke_seconds).timeout.connect(_smoke_timeout)

	if Net.is_server():
		var err := Net.start_server()
		if err != OK:
			_fail("Could not start the server on port %d (error %d)" % [Net.port, err])
			return
		_set_status("Server running on port %d" % Net.port)
		if Net.mode == Net.Mode.HOST:
			spawn_player(1, Net.profile)
	else:
		Net.joined.connect(_on_joined, CONNECT_ONE_SHOT)
		Net.join_failed.connect(_fail)
		var err := Net.join()
		if err != OK:
			_fail("Could not connect (error %d)" % err)
			return
		_set_status("Connecting to %s:%d ..." % [Net.address, Net.port])


func _on_joined() -> void:
	_set_status("Connected, entering the world ...")
	Net.request_spawn.rpc_id(1, Net.profile)


# Server only.
func spawn_player(id: int, p: Dictionary) -> void:
	if players.has_node(str(id)):
		return
	var data := p.duplicate()
	data.id = id
	data.pos = spawn_point
	spawner.spawn(data)
	Net.spawned_count += 1
	print("[server] %s joined as player %d" % [data.name, id])


# Server only.
func despawn_player(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p:
		p.queue_free()


func _make_player(data: Dictionary) -> Node:
	var p := PLAYER_SCENE.instantiate()
	p.setup(data)
	return p


func on_local_player_ready(_p: Node) -> void:
	_set_status("WASD move, Space jump, Shift run, Esc frees the mouse")
	if Net.smoke_seconds > 0.0 and not Net.is_server():
		while _seen.size() < Net.smoke_expect:
			await get_tree().create_timer(0.2).timeout
		print("[client] smoke test passed, saw %d player(s)" % _seen.size())
		# Stay a moment so the other test clients can see this one too.
		await get_tree().create_timer(2.0).timeout
		get_tree().quit(0)


func _set_status(t: String) -> void:
	status.text = t


func _fail(reason: String) -> void:
	push_warning(reason)
	print("[world] " + reason)
	if Net.smoke_seconds > 0.0:
		get_tree().quit(1)
		return
	Net.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://game/boot/boot.tscn")


func _smoke_timeout() -> void:
	if Net.is_server():
		print("[server] smoke run over, %d player(s) joined" % Net.spawned_count)
		get_tree().quit(0 if Net.spawned_count > 0 else 1)
	else:
		print("[client] smoke test failed: saw %d of %d player(s)" % [_seen.size(), Net.smoke_expect])
		get_tree().quit(1)


# ---------------------------------------------------------------- zones

# Loads one of the EA-Godot zone scenes (e.g. res://boomtown.tscn). Those
# scenes carry the zone, sky, sun and the EA runtime look; their free-fly
# camera is removed and its position becomes the spawn point.
func _load_zone(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		print("[world] zone %s not found, using the test map" % path)
		_build_test_map()
		return
	var root: Node = load(path).instantiate()
	var cam := root.get_node_or_null("Camera")
	if cam:
		spawn_point = cam.position
		root.remove_child(cam)
		cam.free()
	if DisplayServer.get_name() == "headless":
		# The dedicated server needs the ground, not the looks.
		var rt := root.get_node_or_null("EARuntime")
		if rt:
			root.remove_child(rt)
			rt.free()
	if Config.ZONE_SPAWNS.has(path):
		spawn_point = Config.ZONE_SPAWNS[path]
	zone_holder.add_child(root)
	var n := _ensure_collision(root)
	print("[world] loaded %s, spawn %s, %d collision meshes added" % [path, spawn_point, n])


# Old EA zone meshes come in without collision. Give the zone's world meshes
# solid collision so players can walk on them. Returns how many were added.
func _ensure_collision(root: Node) -> int:
	if not root.find_children("*", "CollisionObject3D", true, false).is_empty():
		return 0
	var src := root.find_child("World meshes", true, false)
	if src == null:
		src = root
	var count := 0
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			mi.create_trimesh_collision()
			count += 1
	return count


# A flat test map, used when no zone is installed (for example on the
# build server).
func _build_test_map() -> void:
	var size := 200.0 * _u
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0 * _u, size)
	shape.shape = box
	shape.position.y = -0.5 * _u
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.45, 0.30)
	pm.material = mat
	mesh.mesh = pm
	ground.add_child(mesh)
	zone_holder.add_child(ground)

	for i in 12:
		var crate := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cb := BoxShape3D.new()
		var s := (1.0 + (i % 3)) * _u
		cb.size = Vector3(s, s, s)
		cs.shape = cb
		crate.add_child(cs)
		var cm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = cb.size
		cm.mesh = bm
		crate.add_child(cm)
		var a := TAU * i / 12.0
		crate.position = Vector3(cos(a), 0, sin(a)) * 25.0 * _u + Vector3.UP * s / 2.0
		zone_holder.add_child(crate)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	zone_holder.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	zone_holder.add_child(env)
	spawn_point = Vector3(0, 2.0 * _u, 0)
