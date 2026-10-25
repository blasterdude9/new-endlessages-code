# Game-wide tuning values. Endless Ages zones use big units, so player sizes and
# speeds are written in metres and multiplied by UNITS_PER_METER.
# If the player feels too big or too small in a zone, change UNITS_PER_METER.

const UNITS_PER_METER := 40.0

const RUN_SPEED := 7.0         # metres per second
const SPRINT_MULT := 1.6       # Shift
const JUMP_SPEED := 5.5        # metres per second, straight up
const GRAVITY := 16.0          # metres per second squared
const MOUSE_SENSITIVITY := 0.0025

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 32

# The zone the game loads. Any of the EA-Godot zone scenes at res:// works
# (boomtown.tscn, fourfalls.tscn, catacombs.tscn ...). If it is missing, a
# small flat test map is built instead.
const DEFAULT_ZONE := "res://boomtown.tscn"

# Where players appear in a zone (x, z like the in-game map; the height is
# found automatically). Zones not listed use their editor camera position.
const ZONE_SPAWNS := {
	"res://boomtown.tscn": Vector3(0, 300, 0),
}
