#!/usr/bin/env bash
# Starts a dedicated server and two clients with no window, and checks that
# both clients join and see each other.
# Usage: tools/smoke_test.sh <path-to-godot> [zone]   (default zone: built-in test map)
set -u
GODOT="$1"
ZONE="${2:-res://none.tscn}"
cd "$(dirname "$0")/.."
LOG="${TMPDIR:-/tmp}/ea-smoke"
mkdir -p "$LOG"

"$GODOT" --headless --path . -- --server --zone "$ZONE" --smoke-seconds 40 > "$LOG/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 60); do grep -q "listening" "$LOG/server.log" && break; sleep 1; done

"$GODOT" --headless --path . -- --join 127.0.0.1 --name Alpha --race 2 --sex 1 --zone "$ZONE" --smoke-seconds 25 --expect-players 2 > "$LOG/client1.log" 2>&1 &
C1=$!
sleep 1
"$GODOT" --headless --path . -- --join 127.0.0.1 --name Beta --race 1 --zone "$ZONE" --smoke-seconds 25 --expect-players 2 > "$LOG/client2.log" 2>&1
R2=$?
wait $C1; R1=$?
wait $SERVER; RS=$?

for f in server client1 client2; do echo "== $f"; grep -E '^\[' "$LOG/$f.log"; done
grep -h -E "SCRIPT ERROR|Parse Error" "$LOG"/*.log && exit 1
echo "server=$RS client1=$R1 client2=$R2"
[ $RS -eq 0 ] && [ $R1 -eq 0 ] && [ $R2 -eq 0 ]
