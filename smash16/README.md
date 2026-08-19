# SMASH 16

A 16-bit platform fighter. You don't drain a health bar — you build up a
damage **percent**, and the higher that number climbs the further you fly when
you get hit. You win by knocking the other fighter clean off the screen.

## Controls

|            | Player 1        | Player 2               |
|------------|-----------------|------------------------|
| Move       | `A` / `D`       | `←` / `→`              |
| Aim up     | `W`             | `↑`                    |
| Aim down / fast fall / drop through | `S` | `↓`      |
| Jump       | `SPACE`         | `RIGHT SHIFT` (or `KP0`) |
| Attack     | `F`             | `.` (or `KP1`)         |
| Special    | `G`             | `/` (or `KP2`)         |
| Shield     | `C`             | `,` (or `KP3`)         |

Jump has its own key rather than being "tap up". Tap-jump makes grounded
up-attacks basically unreachable, and up-attacks are half your combo game.

On the select screen: `TAB` toggles Player 2 between CPU and a second human,
`G` cycles CPU difficulty, `1`–`5` sets the stock count.

## The moves

Direction + attack gives you a different move, on the ground and in the air:

- **Attack** alone — jab. Fast, weak, safe.
- **Side + attack** — your main kill move on the ground.
- **Up + attack** — hits above you.
- **Down + attack** — low, weak knockback, good for starting a combo.
- **In the air**: neutral / forward / up / **down**. Down-air is a **spike** —
  it fires them straight down. Off the side of the stage that is an early kill
  and the most satisfying hit in the game.
- **Special** — each fighter's own move.
- **Up + special** — your recovery. Afterwards you are **helpless**: no jumps,
  no attacks, only drift, until you touch the ground. That rule is what makes
  getting knocked off genuinely frightening.
- **Shield** — blocks, but it shrinks while held and *breaks* if you overuse
  it. Shield + a direction rolls; shield + down spot-dodges; shield in the air
  is an air dodge.

## The roster

| Fighter | From | The idea |
|---|---|---|
| Mega Man X | Mega Man X3 | Chargeable buster, air dash |
| Samus | Super Metroid | Heavy but floaty, biggest charge shot, Screw Attack recovery |
| Link | Zelda II | Longest reach, boomerang, poor recovery |
| Kirby | Kirby Super Star | Five jumps, very floaty, feather light |
| Fox | *invented* | Fastest, falls like a brick, blaster chips away |
| Mario | Super Mario World | The benchmark all-rounder |
| Ness | *invented* | Floaty with brutal aerials, the bat kills |
| Yoshi | Super Mario World | Heavy, but the flutter jump gets him home |
| Zero | Mega Man X3 | No projectile — just the Z-Saber, and it outreaches you |

**All art is drawn from scratch**, in `Art.gd`, at one consistent scale and
palette depth. Nothing is ripped from any ROM. That is partly the legally
clean choice, but mostly a practical one: Super Metroid Samus, Kirby Super
Star Kirby and Zelda II Link are drawn at wildly different sizes and styles,
and dropping the originals into one game would look like a ransom note. Real
Smash redraws everybody in one house style for exactly this reason.

Star Fox on the SNES is a 3D rail shooter and EarthBound is top-down, so no
side-view sprite exists for Fox or Ness. Those two are invented.

## How the code is laid out

| File | What it does |
|---|---|
| `Rules.gd` | Stage geometry, physics constants, **the knockback formula** |
| `Chars.gd` | The roster. One dictionary per fighter — all the tuning numbers |
| `Moves.gd` | Every attack's frame data, plus specials and projectiles |
| `Fighter.gd` | Physics, state machine, hit detection, taking a hit |
| `Art.gd` | All the drawing. Three body plans + a per-character detail pass |
| `Brain.gd` | The CPU. Produces the same input a keyboard does — no cheating |
| `Projectile.gd` | Shots, with their own hit resolution |
| `Stage.gd` `Fx.gd` `Hud.gd` `Ui.gd` `Sfx.gd` | Backdrop, sparks, HUD, menus, sound |
| `Main.gd` | Screens and the main 60Hz loop |

Two deliberate engineering choices worth knowing:

**No `CharacterBody2D`.** Godot's physics engine is built for platformers with
slopes and rigid bodies. A platform fighter needs frame-exact hand-tuned
kinematics, so collision is hand-rolled AABB on a fixed 60Hz tick. Every
number is a knob.

**Everything runs on `_physics_process` at a fixed 60Hz.** Startup and recovery
are counted in *frames*. If those frames got longer on a slow machine the whole
game would change speed.

## Adding a fighter

1. Append a dictionary to `Chars.LIST` — stats, palette, `plan`, `kit`.
2. If they need a new special, add it to `Moves.SPECIALS` (and `Moves.SHOTS`
   if it fires something) plus `Moves.UP_SPECIALS`.
3. Add a `match` case in `Art._details()` for their hat / weapon / tail.

The select grid is 5 columns wide and adds rows automatically.

## Tuning the feel

Almost everything lives in `Rules.gd`:

- `GRAV`, `MAXFALL`, `FASTFALL` — how heavy the air feels
- `KB_SCALE`, `KB_DECAY` — how far hits send people
- `HITSTUN_PER_KB` — how long they can't fight back
- `JUMPSQUAT` — how committed a jump feels

Per-fighter numbers are in `Chars.gd`. Per-move frame data is in `Moves.gd`.

## Seeing it run without a human

```
godot --path smash16 -- --autotest
```

Drives itself through title → select → a full CPU-vs-CPU match, printing
percents and saving screenshots to the user data directory. Useful for
checking art and balance without having to play it yourself.

## Building for web

```
godot --headless --path smash16 --export-release "Web" export/web/index.html
```

Keep `variant/thread_support=false` in the export preset — the threaded build
needs COOP/COEP headers a plain static server does not send. Godot web exports
also **must be served over HTTPS**, or they load and then stop with
"Secure Context - Check web server configuration", which looks like a broken
build rather than a broken URL.
