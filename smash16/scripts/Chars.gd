extends RefCounted
class_name Chars

# ---------------------------------------------------------------------------
# THE ROSTER
#
# Eight fighters. All of them are drawn from scratch in Art.gd -- no sprites
# ripped out of any ROM. They are deliberately all built to ONE scale and ONE
# palette depth so they look like they belong in the same game, which is the
# same thing real Smash does when it redraws everybody.
#
# WHAT THE NUMBERS MEAN
#   weight    how hard you are to launch. Higher = you survive to a higher %.
#   power     damage multiplier on everything you throw.
#   size      visual and hurtbox scale. Bigger = easier to hit.
#   speed     top ground run speed (px/frame)
#   accel     how fast you get up to that speed
#   air_acc   how much you can steer while airborne
#   air_max   top horizontal air speed
#   jump      first jump velocity (negative is up)
#   hop       short hop, if you tap jump instead of holding it
#   jumps     total jumps including the one off the floor
#   grav_mul  gravity multiplier. Under 1.0 is floaty, over 1.0 is a fastfaller.
#   rise      how hard the up-special throws you
#   reach     hitbox length multiplier -- swords and cannons get more than fists
#
# The trade every fighter makes: light + floaty = easy to launch but easy to
# recover; heavy + fast-falling = survives forever but dies instantly if it
# gets knocked below the stage.
# ---------------------------------------------------------------------------

static var LIST: Array = [

	# -- 1 -- MEGA MAN X (Mega Man X3) -------------------------------------
	# Rounded blue armour, shoulder pads, helmet with a forward fin, and the
	# X-Buster on the right arm. Mobile and technical: he has an air dash.
	{
		"id": "x", "name": "MEGA MAN X", "from": "MEGA MAN X3",
		"blurb": "Charge the X-Buster. Air dash to close in.",
		"plan": "humanoid",
		"weight": 96.0, "power": 1.00, "size": 1.00,
		"speed": 2.60, "accel": 0.62, "air_acc": 0.26, "air_max": 2.45,
		"jump": -7.4, "hop": -5.3, "jumps": 2, "grav_mul": 1.02,
		"rise": -9.3, "reach": 1.00,
		"special": "buster", "up_special": "boost", "air_dash": true,
		"pal": {
			"main":   Color("2c6fd8"), "main2": Color("174a9e"),
			"trim":   Color("8fd0ff"), "skin":  Color("f6c9a0"),
			"dark":   Color("101a33"), "hair":  Color("3a2a1e"),
			"accent": Color("f2e14a"), "metal": Color("cfd8e6"),
		},
		"kit": {"helmet": "fin", "cannon": "right", "visor": false},
	},

	# -- 2 -- SAMUS (Super Metroid) ----------------------------------------
	# The Power Suit: big shoulders, green-and-orange plates, green visor,
	# and the arm cannon. Heavy but floaty, with the longest recovery here.
	{
		"id": "samus", "name": "SAMUS", "from": "SUPER METROID",
		"blurb": "Hold special to charge. Screw Attack gets you home.",
		"plan": "humanoid",
		"weight": 108.0, "power": 1.05, "size": 1.06,
		"speed": 2.15, "accel": 0.46, "air_acc": 0.27, "air_max": 2.30,
		"jump": -7.2, "hop": -5.1, "jumps": 2, "grav_mul": 0.86,
		"rise": -10.2, "reach": 1.10,
		"special": "charge", "up_special": "screw", "air_dash": false,
		"pal": {
			"main":   Color("e8862c"), "main2": Color("b8571a"),
			"trim":   Color("f2c85a"), "skin":  Color("f6c9a0"),
			"dark":   Color("2a1408"), "hair":  Color("c8a028"),
			"accent": Color("46c86a"), "metal": Color("d8dcc0"),
		},
		"kit": {"helmet": "dome", "cannon": "right", "visor": true},
	},

	# -- 3 -- LINK (Zelda II, redrawn) -------------------------------------
	# Zelda II's Link was an 8-bit side-view sprite: tall, thin, sword out
	# front, shield up. Same silhouette here, but with 16-bit shading so he
	# stands next to Samus without looking like a different console.
	{
		"id": "link", "name": "LINK", "from": "ZELDA II",
		"blurb": "Longest reach in the game. Boomerang and Spin Attack.",
		"plan": "humanoid",
		"weight": 104.0, "power": 1.05, "size": 1.02,
		"speed": 2.25, "accel": 0.52, "air_acc": 0.22, "air_max": 2.20,
		"jump": -7.3, "hop": -5.2, "jumps": 2, "grav_mul": 1.08,
		"rise": -8.6, "reach": 1.22,
		"special": "boomerang", "up_special": "spinatk", "air_dash": false,
		"pal": {
			"main":   Color("3fa84a"), "main2": Color("246b2c"),
			"trim":   Color("f0e0b0"), "skin":  Color("f6c9a0"),
			"dark":   Color("12240f"), "hair":  Color("d8a838"),
			"accent": Color("2c6fd8"), "metal": Color("c8ccd8"),
		},
		"kit": {"helmet": "cap", "sword": true, "shield": true},
	},

	# -- 4 -- KIRBY (Kirby Super Star) -------------------------------------
	# A pink ball with feet. Five jumps and very low gravity, so he is
	# almost impossible to kill off the side -- but he is feather light,
	# so he starts flying at percentages nobody else worries about.
	{
		"id": "kirby", "name": "KIRBY", "from": "KIRBY SUPER STAR",
		"blurb": "Five jumps. Nearly impossible to knock out of the sky.",
		"plan": "ball",
		"weight": 72.0, "power": 0.90, "size": 0.80,
		"hurt_w": 1.50, "hurt_h": 0.88,
		"speed": 2.20, "accel": 0.66, "air_acc": 0.32, "air_max": 2.40,
		"jump": -6.9, "hop": -4.8, "jumps": 5, "grav_mul": 0.70,
		"rise": -9.0, "reach": 0.92,
		"special": "hammer", "up_special": "cutter", "air_dash": false,
		"pal": {
			"main":   Color("f49ac1"), "main2": Color("d4739b"),
			"trim":   Color("ffd0e2"), "skin":  Color("f49ac1"),
			"dark":   Color("3a1526"), "hair":  Color("f49ac1"),
			"accent": Color("e03c5a"), "metal": Color("c8ccd8"),
		},
		"kit": {"blush": true, "feet": "big"},
	},

	# -- 5 -- FOX (invented -- no SNES side-scroller exists) ---------------
	# Star Fox on the SNES is a 3D rail shooter, so there is no side-view
	# sprite anywhere to work from. This one is made up: pilot jacket,
	# boots, muzzle, ears, and a tail that swings when he moves.
	{
		"id": "fox", "name": "FOX", "from": "STAR FOX (new sprite)",
		"blurb": "Fastest here, and falls like a brick. Blaster chips away.",
		"plan": "humanoid",
		"weight": 78.0, "power": 0.92, "size": 0.96,
		"speed": 3.20, "accel": 0.80, "air_acc": 0.26, "air_max": 2.55,
		"jump": -7.6, "hop": -5.3, "jumps": 2, "grav_mul": 1.30,
		"rise": -10.6, "reach": 0.96,
		"special": "blaster", "up_special": "firefox", "air_dash": false,
		"pal": {
			"main":   Color("d8d2c0"), "main2": Color("a89a78"),
			"trim":   Color("5aa8d8"), "skin":  Color("e08c3c"),
			"dark":   Color("2a1c10"), "hair":  Color("e08c3c"),
			"accent": Color("46c86a"), "metal": Color("c8ccd8"),
		},
		"kit": {"ears": true, "muzzle": true, "tail": true},
	},

	# -- 6 -- MARIO (Super Mario World) ------------------------------------
	# The benchmark. Nothing he does is the best, nothing he does is bad.
	# If a new fighter feels wrong, fight Mario and work out which number.
	{
		"id": "mario", "name": "MARIO", "from": "SUPER MARIO WORLD",
		"blurb": "The all-rounder. Bouncing fireball, Super Jump Punch.",
		"plan": "humanoid",
		"weight": 98.0, "power": 1.00, "size": 0.96,
		"speed": 2.45, "accel": 0.58, "air_acc": 0.25, "air_max": 2.35,
		"jump": -7.4, "hop": -5.3, "jumps": 2, "grav_mul": 1.00,
		"rise": -9.4, "reach": 0.98,
		"special": "fireball", "up_special": "punch", "air_dash": false,
		"pal": {
			"main":   Color("d83c30"), "main2": Color("a02420"),
			"trim":   Color("f0e8d0"), "skin":  Color("f6c090"),
			"dark":   Color("1c1018"), "hair":  Color("6b3a18"),
			"accent": Color("2c58c8"), "metal": Color("f2c84a"),
		},
		"kit": {"helmet": "cap", "mustache": true, "overalls": true},
	},

	# -- 7 -- NESS (invented -- EarthBound is top-down) --------------------
	# EarthBound never shows Ness from the side, so this is made up too:
	# striped shirt, backpack, ball cap, and the bat for heavy swings.
	{
		"id": "ness", "name": "NESS", "from": "EARTHBOUND (new sprite)",
		"blurb": "Floaty with brutal aerials. The bat is a kill move.",
		"plan": "humanoid",
		"weight": 94.0, "power": 1.02, "size": 0.88,
		"speed": 2.30, "accel": 0.54, "air_acc": 0.29, "air_max": 2.30,
		"jump": -7.2, "hop": -5.1, "jumps": 2, "grav_mul": 0.90,
		"rise": -9.6, "reach": 1.06,
		"special": "pkfire", "up_special": "pkt", "air_dash": false,
		"pal": {
			"main":   Color("e04848"), "main2": Color("a82c2c"),
			"trim":   Color("f2f0e4"), "skin":  Color("f6c9a0"),
			"dark":   Color("1a1420"), "hair":  Color("2a1a10"),
			"accent": Color("f2c84a"), "metal": Color("9a7a4a"),
		},
		"kit": {"helmet": "cap", "backpack": true, "stripes": true, "bat": true},
	},

	# -- 8 -- YOSHI (Super Mario World) ------------------------------------
	# Heavy, but with the best air control on the roster thanks to the
	# flutter -- his second jump keeps lifting while you hold it.
	{
		"id": "yoshi", "name": "YOSHI", "from": "SUPER MARIO WORLD",
		"blurb": "Heavy, but the flutter jump gets him back from anywhere.",
		"plan": "dino",
		"weight": 112.0, "power": 1.00, "size": 1.10,
		"hurt_w": 1.20, "hurt_h": 1.00,
		"speed": 2.40, "accel": 0.56, "air_acc": 0.34, "air_max": 2.60,
		"jump": -7.3, "hop": -5.2, "jumps": 2, "grav_mul": 0.94,
		"rise": -6.2, "reach": 1.04,
		"special": "egg", "up_special": "eggtoss", "flutter": true,
		"pal": {
			"main":   Color("46c83c"), "main2": Color("2a8a26"),
			"trim":   Color("f2f0e0"), "skin":  Color("f2e0a0"),
			"dark":   Color("122a10"), "hair":  Color("e05a2c"),
			"accent": Color("e05a2c"), "metal": Color("d84040"),
		},
		"kit": {"snout": true, "saddle": true, "shoes": true, "tail": true},
	},

	# -- 9 -- ZERO (Mega Man X3) -------------------------------------------
	# Red armour, blond ponytail, and the Z-Saber. Deliberately built as X's
	# opposite: X keeps you away with the buster, Zero has no real projectile
	# and has to get in your face -- but the saber outreaches almost everyone
	# and he hits harder than anything else this fast.
	{
		"id": "zero", "name": "ZERO", "from": "MEGA MAN X3",
		"blurb": "No projectile. Just the Z-Saber, and it outreaches you.",
		"plan": "humanoid",
		"weight": 94.0, "power": 1.18, "size": 1.02,
		"speed": 2.95, "accel": 0.72, "air_acc": 0.27, "air_max": 2.50,
		"jump": -7.5, "hop": -5.3, "jumps": 2, "grav_mul": 1.08,
		"rise": -9.6, "reach": 1.26,
		"special": "dashslash", "up_special": "risingsaber", "air_dash": true,
		"pal": {
			"main":   Color("d02c34"), "main2": Color("8e1a24"),
			"trim":   Color("f0e0e4"), "skin":  Color("f6c9a0"),
			"dark":   Color("1e0e14"), "hair":  Color("f2d24a"),
			"accent": Color("46e0d0"), "metal": Color("cfd8e6"),
		},
		"kit": {"helmet": "zero", "ponytail": true, "saber": true},
	},
]

static func get_char(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]

static func count() -> int:
	return LIST.size()

static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0
