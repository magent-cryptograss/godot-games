# maps/

Maps saved from the in-game map editor land here, as JSON.

These are the **real** ones: they are committed to git and they ship with the
game. Anything in this folder overrides the world that `World.gd` generates in
code, so a map file here is the final word on what that map looks like.

There is a second, temporary layer at `user://maps/` — on this machine that is
`~/.local/share/godot/app_userdata/SONGBOUND/maps/`. A file there sits *on top*
of the copy in this folder, which is useful for trying a change without
committing it. Delete the scratch file to go back to the shipped map.

The editor writes here whenever it can, and only falls back to the scratch
folder in an exported build, where `res://` is read-only. Saving here also
clears any stale scratch copy of the same map, so what you just saved is what
the game actually loads.

Editing the JSON by hand is fine — it is plain text, and `tiles` is simply the
map read left to right, top to bottom, one character per tile.
