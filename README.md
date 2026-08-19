# Godot Games

Small games built with Godot 4.6.

## Games

### Ralph the Wonder Llama
Side-scrolling adventure where Ralph must avoid dragons and forks to reach the cigar box at the end of the level, where he must lightly tap it with a hammer.

- **Controls:** A/D to move, Space to jump, E to tap
- **Play:** https://fibonacci1.hunter.cryptograss.live

### Joe the Crab: Shell Quest
Overhead adventure where Joe the Crab explores the beach, tide pools, and coral reef to upgrade his shell to a turtle shell. Avoid seagulls, talk to friendly crabs, collect sand dollars, and find three shell upgrades.

- **Controls:** WASD to move, F to pinch, E to interact
- **Play:** https://fibonacci2.hunter.cryptograss.live

### Mega Man X7 16-bit
A Link to the Past-style overhead action demake of Mega Man X7. Play as Axl (and unlock X by rescuing reploids!) through procedurally-generated rooms, fighting Maverick enemies with your buster and dash.

- **Controls:** WASD to move, Z to jump/confirm, X to shoot, C to dash
- **Play:** https://fibonacci3.hunter.cryptograss.live

### Songbound
A 16-bit RPG where music replaces magic. Draw your own sprite pixel by pixel (or pick one of eight), choose an instrument that changes both your stats and how your songs sound, then pick GENERAL or one of eight elements at every level-up. Level 1 and every level ending in 5 or 0 teaches a song — eight per element, sixty-four in all, to level 100. Songs are the only memory that lasts, and the instruments that have been abandoned are past mending.

- **Controls:** Arrows/WASD to move, Z confirm, X back, C menu — mouse works everywhere
- **Play:** https://fibonacci0.hunter.cryptograss.live/games/songbound-godot/index.html
- **Map editor:** open `songbound/scenes/MapEditor.tscn` in Godot and press F6 — see `songbound/MAP_EDITOR.md`

### Pickin' Defense
Tower defense where evil instruments attack the bluegrass stage. Place good instruments to blast the rogue ones with music. Eight towers, 100 waves.

- **Controls:** Mouse only — click to select an instrument, click a square to place it
- **Play:** https://fibonacci0.hunter.cryptograss.live/games/pickin-defense/index.html

### Smash 16
A 16-bit platform fighter. You don't drain a health bar — you build up a damage **percent**, and the higher it climbs the further you fly when you get hit. Win by knocking them clean off the screen. Nine fighters (Mega Man X, Samus, Link, Kirby, Fox, Mario, Ness, Yoshi, Zero), each with their own special and recovery. Two players on one keyboard, or fight the CPU.

- **Controls:** P1 — A/D move, W/S aim, SPACE jump, F attack, G special, C shield. P2 — arrows, RSHIFT jump, `.` attack, `/` special, `,` shield
- **Play:** https://fibonacci0.hunter.cryptograss.live/games/smash16/index.html
- All art drawn from scratch in `smash16/scripts/Art.gd` — see `smash16/README.md`

## Notes on web builds

Godot web exports **must be served over HTTPS**. Without a secure context they
load and then stop with "Secure Context - Check web server configuration",
which looks like a broken build rather than a broken URL.

Keep `variant/thread_support=false` in the export preset. The threaded build
needs COOP/COEP headers a plain static server does not send.
