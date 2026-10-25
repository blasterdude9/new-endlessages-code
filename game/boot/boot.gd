extends Control
# Start screen: make a character (name, race, sex) and join or host a game.
#
# Command line (put game options after "--"):
#   --server              run a dedicated server (no window needed: add --headless)
#   --host                host and play on this PC, skipping this screen
#   --join <address>      skip this screen and join that server
#   --port <n>            port to host on or join (default 7777)
#   --zone <res://...>    zone scene to load (default res://boomtown.tscn)
#   --name <n> --race <0-3> --sex <0-1>
#   --smoke-seconds <s>   automated test: quit after this long (exit code 0 = ok)
#   --expect-players <n>  automated test: the client passes once it sees n players

const Config := preload("res://game/common/config.gd")
const Races := preload("res://game/common/races.gd")

var _name: LineEdit
var _race: OptionButton
var _sex: OptionButton
var _address: LineEdit
var _error: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args := _parse_args()
	if args.has("server") or args.has("host") or args.has("join"):
		_apply_args(args)
		if args.has("server"):
			Net.mode = Net.Mode.DEDICATED
		elif args.has("host"):
			Net.mode = Net.Mode.HOST
		else:
			Net.mode = Net.Mode.CLIENT
			Net.address = args.join
		_enter_world.call_deferred()
		return
	_build_menu()


func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "Endless Ages"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_name = LineEdit.new()
	_name.placeholder_text = "Character name"
	_name.max_length = 20
	_name.text = Net.profile.name
	box.add_child(_labelled("Name", _name))

	_race = OptionButton.new()
	for r in Races.NAMES:
		_race.add_item(r)
	_race.selected = Net.profile.race
	box.add_child(_labelled("Race", _race))

	_sex = OptionButton.new()
	for s in Races.SEXES:
		_sex.add_item(s)
	_sex.selected = Net.profile.sex
	box.add_child(_labelled("Sex", _sex))

	_address = LineEdit.new()
	_address.text = Net.address
	box.add_child(_labelled("Server", _address))

	var join := Button.new()
	join.text = "Join server"
	join.pressed.connect(_on_join)
	box.add_child(join)

	var host := Button.new()
	host.text = "Host and play (on this PC)"
	host.pressed.connect(_on_host)
	box.add_child(host)

	_error = Label.new()
	_error.modulate = Color(1, 0.5, 0.5)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_error)


func _labelled(text: String, field: Control) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row


func _read_menu() -> void:
	Net.profile = Races.sanitize({"name": _name.text, "race": _race.selected, "sex": _sex.selected})


func _on_join() -> void:
	_read_menu()
	Net.address = _address.text.strip_edges()
	if Net.address.is_empty():
		_error.text = "Type the server address first."
		return
	Net.mode = Net.Mode.CLIENT
	_enter_world()


func _on_host() -> void:
	_read_menu()
	Net.mode = Net.Mode.HOST
	_enter_world()


func _enter_world() -> void:
	get_tree().change_scene_to_file("res://game/world/world.tscn")


func _parse_args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var key: String = a[i].trim_prefix("--")
		if key == "server" or key == "host":
			out[key] = true
		elif i + 1 < a.size():
			out[key] = a[i + 1]
			i += 1
		i += 1
	return out


func _apply_args(args: Dictionary) -> void:
	if args.has("port"):
		Net.port = int(args.port)
	if args.has("zone"):
		Net.zone = args.zone
	if args.has("smoke-seconds"):
		Net.smoke_seconds = float(args["smoke-seconds"])
	if args.has("expect-players"):
		Net.smoke_expect = int(args["expect-players"])
	Net.profile = Races.sanitize({
		"name": args.get("name", Net.profile.name),
		"race": args.get("race", Net.profile.race),
		"sex": args.get("sex", Net.profile.sex),
	})
