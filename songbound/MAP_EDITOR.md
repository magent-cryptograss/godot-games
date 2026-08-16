# The map editor

Open the Godot project, select `scenes/MapEditor.tscn`, and press **F6** (run
current scene). Or set it as the main scene while you work.

## Where your maps go

Two layers, and the editor picks the right one for you.

| | |
|---|---|
| `maps/` in the project | **the real ones.** Committed to git, ship with the game |
| `user://maps/` | a scratch layer laid on top, for trying something uncommitted |

On this machine the scratch folder is
`~/.local/share/godot/app_userdata/SONGBOUND/maps/`.

Pressing `S` writes to the **project** folder whenever it can, which is
whenever you run from inside Godot. It only falls back to scratch in an
exported build, where `res://` is read-only. The status line tells you which
one it used.

A saved map overrides the world `World.gd` generates in code, so you can redraw
one corner of the game and leave everything else alone. Delete the JSON to go
back to the generated version.

Saving to the project folder also **clears any stale scratch copy of that map**,
because otherwise the scratch file would still win at load time and quietly
hide the thing you just saved.

## Controls

**Getting around**

| | |
|---|---|
| `[` `]` | previous / next map (10 of them) |
| arrows / WASD | pan |
| `-` `+` | zoom (4, 8 or 16 pixels per tile) |
| `G` | toggle the grid |

**Painting tiles** (the default mode)

| | |
|---|---|
| left click | paint the selected tile |
| right click | eyedropper — pick up the tile under the cursor |
| click the palette | choose a tile |
| `F` | flood fill from the cursor |
| `U` | undo (40 deep) |

The panel under the palette tells you the tile's name and whether it is
**solid** or **walk** — worth watching, since a wall of walkable tiles or a
path of solid ones is the easiest mistake to make.

**Placing things** — press `TAB`, or just press one of the number keys

| | |
|---|---|
| `1` | player start (the `@` marker) |
| `2` | NPC |
| `3` | chest |
| `4` | warp |
| `5` | boss |
| `,` `.` | cycle the thing you're placing — NPC look, chest contents, warp destination |
| `DEL` | remove whatever is under the cursor |

Markers on the map: `@` start, `N` npc, `S` sign, `C` chest, `W` warp, `B` boss.

**Saving**

| | |
|---|---|
| `S` | save this map (the path is printed and shown on screen) |
| `R` | reload this map from disk, discarding changes |

## Notes worth knowing

**Dialogue lives in `Story.gd`, not in the map.** An NPC you place stores a
*key* like `MINER`, and the words are looked up at runtime. That keeps map files
small and means you can rewrite dialogue without touching any map. The
available keys are in `Story.LINE_KEYS`; add a new one by adding it to that
list and to `Story.lines_for()`.

**Warps land on the destination's start tile** by default. If you want a warp
to arrive somewhere else, edit `tx`/`ty` in the JSON — it's plain text and
readable.

**Two rules the game will hold you to**, both checked by
`tests/TestField.tscn`:

- Every warp must land on a walkable tile.
- A warp must not land directly on top of a return warp, or you bounce between
  two maps forever.

Run that test after a big edit and it will tell you if you've broken the world:

    godot --headless --path <project> res://tests/TestField.tscn

It also flood-fills the overworld from the town gate and fails if the cave
mouth has become unreachable — which is exactly the bug that carving a road
before stamping a mountain ring produced the first time.

## Committing your maps

Nothing to do: `S` already writes into `maps/` in the project, so
`git add maps/` and they are in. They are plain JSON and diff readably --
`tiles` is just the map left to right, top to bottom, one character per tile.

If you want to try a change *without* committing it, edit and save from an
exported build, or drop a copy into `user://maps/` by hand. That file wins
until you delete it.
