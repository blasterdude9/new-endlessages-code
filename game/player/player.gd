extends CharacterBody3D
# A player in the world. The local player gets a first-person camera and
# WASD movement; everyone else is drawn as a placeholder body for their race.
# Position and facing are sent to the others by the MultiplayerSynchronizer.
# For now each client moves its own player; the server takes over movement
# in the multiplayer stage of the plan.

const Config := preload("res://game/common/config.gd")
const Races := preload("res://game/common/races.gd")

var peer_id := 1
var char_name := "Player"
var race := 0
var sex := 0
var spawn_point := Vector3.ZERO

var _u := Config.UNITS_PER_METER
var _pitch := 0.0
var _placed := false
var _place_tries := 0
var _head: Node3D
var _camera: Camera3D


# Called by the spawner on every machine before the player enters the tree.
func setup(data: Dictionary) -> void:
	peer_id = data.id
	char_name = data.name
	race = data.race
	sex = data.sex
	spawn_point = data.pos
	position = data.pos
	name = str(peer_id)
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	var b := Races.body(race, sex)
	var h: float = b.height * _u
	var r: float = b.radius * _u

	var shape := CapsuleShape3D.new()
	shape.height = h
	shape.radius = r
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = h / 2.0
	add_child(col)

	var mesh := CapsuleMesh.new()
	mesh.height = h
	mesh.radius = r
	var mat := StandardMaterial3D.new()
	mat.albedo_color = b.color
	mesh.material = mat
	var body := MeshInstance3D.new()
	body.mesh = mesh
	body.position.y = h / 2.0
	add_child(body)

	var tag := Label3D.new()
	tag.text = "%s\n%s" % [char_name, Races.label(race, sex)]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004 * _u
	tag.position.y = h + 0.35 * _u
	add_child(tag)

	_head = Node3D.new()
	_head.position.y = h * 0.92
	add_child(_head)

	floor_snap_length = 0.3 * _u
	floor_max_angle = deg_to_rad(50)

	if is_multiplayer_authority():
		body.visible = false
		tag.visible = false
		_camera = Camera3D.new()
		_camera.near = 0.05 * _u
		_camera.far = 60000.0
		_camera.fov = 80
		_head.add_child(_camera)
		_camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("[client] spawned as %s (%s)" % [char_name, Races.label(race, sex)])
		if Net.world:
			Net.world.on_local_player_ready(self)


func _unhandled_input(e: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * Config.MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - e.relative.y * Config.MOUSE_SENSITIVITY, -1.5, 1.5)
		_head.rotation.x = _pitch
	elif e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority():
		return
	if not _placed:
		# Wait until standing on the zone before moving (collision can take a
		# few frames to be ready after the zone loads).
		_placed = _drop_to_ground()
		_place_tries += 1
		if not _placed and _place_tries < 30:
			return
		_placed = true

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += transform.basis.x
	dir.y = 0
	var speed := Config.RUN_SPEED * _u
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= Config.SPRINT_MULT
	dir = dir.normalized() * speed
	velocity.x = dir.x
	velocity.z = dir.z

	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = Config.JUMP_SPEED * _u
	else:
		velocity.y -= Config.GRAVITY * _u * dt
	move_and_slide()

	# Fell out of the world: put the player back at the spawn point.
	if position.y < spawn_point.y - 1000.0 * _u:
		position = spawn_point
		velocity = Vector3.ZERO
		_drop_to_ground()


# Stand on the ground nearest the spawn point. Zones only give a rough start
# position, which can be over water or a hole, so search outward in rings
# until ground is found. Returns false if no ground was found.
func _drop_to_ground() -> bool:
	var space := get_world_3d().direct_space_state
	var step := 25.0 * _u
	for ring in 80:
		var count := 1 if ring == 0 else ring * 8
		for i in count:
			var a := TAU * i / count
			var p := spawn_point + Vector3(cos(a), 0, sin(a)) * step * ring
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 500.0 * _u, p + Vector3.DOWN * 2000.0 * _u)
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			if hit:
				position = hit.position + Vector3.UP * 0.05 * _u
				velocity = Vector3.ZERO
				return true
	return false
