# Playable races. Every race has a male and a female body.
# Until the real character models exist, each body is a coloured capsule
# with its own height and width so the races are easy to tell apart.

const NAMES := ["Human", "Blob", "Frog", "Reptilian"]
const SEXES := ["Male", "Female"]

const BODIES := [
	{"height": 1.80, "radius": 0.35, "color": Color(0.86, 0.70, 0.56)},  # Human
	{"height": 1.30, "radius": 0.55, "color": Color(0.36, 0.60, 0.95)},  # Blob
	{"height": 1.50, "radius": 0.40, "color": Color(0.38, 0.80, 0.30)},  # Frog
	{"height": 1.95, "radius": 0.38, "color": Color(0.60, 0.52, 0.22)},  # Reptilian
]

const FEMALE_SCALE := 0.93


# Body size in metres and colour for a race and sex.
static func body(race: int, sex: int) -> Dictionary:
	var b: Dictionary = BODIES[clampi(race, 0, BODIES.size() - 1)].duplicate()
	if sex == 1:
		b.height *= FEMALE_SCALE
		b.radius *= FEMALE_SCALE
		b.color = b.color.lightened(0.15)
	return b


static func label(race: int, sex: int) -> String:
	return "%s %s" % [SEXES[clampi(sex, 0, 1)], NAMES[clampi(race, 0, NAMES.size() - 1)]]


# Clean up a character sent by a client so the server never trusts bad values.
static func sanitize(p: Dictionary) -> Dictionary:
	var name := str(p.get("name", "Player")).strip_edges().left(20)
	if name.is_empty():
		name = "Player"
	return {
		"name": name,
		"race": clampi(int(p.get("race", 0)), 0, NAMES.size() - 1),
		"sex": clampi(int(p.get("sex", 0)), 0, 1),
	}
