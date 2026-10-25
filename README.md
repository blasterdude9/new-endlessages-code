# Endless Ages remake (EA-Godot)

A modern remake of Endless Ages in Godot 4.7: the same world, races and FPS RPG
gameplay on a current engine. This repository is the EA-Godot project: the
zones, models and textures converted from Endless Ages, plus the new game code.

Plan and roadmap: https://claude.ai/artifact/Ee8tPFFv6J3Pc3eroa14CU

## What is where

| Folder | What it holds |
| --- | --- |
| `game/` | The new game: start menu, networking, world, players |
| `zones/`, `models/`, `textures/`, `textures_hd/` | Endless Ages content converted to Godot |
| `scripts/`, `shaders/`, `addons/ea_tools/` | The EA look (sky, water, foliage, effects) and the editor tools |
| `*.tscn` at the top | One scene per zone (`boomtown.tscn`, `fourfalls.tscn` ...) |
| `tools/` | Test scripts |

Big art files (models, textures, sounds) are stored with Git LFS. Install it
once with `git lfs install` before cloning.

## Playing

Open the project in Godot 4.7 and press Play (F5). The start screen lets you
pick a name, race (Human, Blob, Frog, Reptilian) and sex, then:

- **Host and play** runs the server inside your game, so friends can join you.
- **Join server** connects to someone else's server by address.

Controls: WASD move, mouse look, Space jump, Shift run, Esc frees the mouse.

The game loads Boomtown by default. To change it, edit `DEFAULT_ZONE` in
`game/common/config.gd`. If players look too big or too small for a zone,
change `UNITS_PER_METER` in the same file.

Races are coloured capsules for now, with a different size per race and sex,
until the character models are brought over from Endless Ages.

## Dedicated server

Run the server with no window:

```
Godot_v4.7.1-stable_win64.exe --headless --path C:\Users\blast\EA-Godot -- --server --port 7777
```

Players join it with **Join server** and the server PC's address. Open UDP
port 7777 in the firewall for players outside your network.

More command line options are listed at the top of `game/boot/boot.gd`.

## Testing

`tools/smoke_test.sh <godot>` starts a server and two clients with no window
and checks that both join and see each other. GitHub runs it on every push.
