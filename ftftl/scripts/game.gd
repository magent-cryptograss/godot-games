extends Node2D

# ================================================================
# FTFTL: FASTER THAN FASTER THAN LIGHT
# Spaceship roguelike — manage crew, fight ships, upgrade systems
# More weapons, ships, crew, events, and augments than you can handle
# ================================================================

const SW = 960
const SH = 640

enum State { TITLE, HANGAR, MAP, COMBAT, EVENT, SHOP, UPGRADE, GAMEOVER, VICTORY }

var state = State.TITLE
var frame = 0
var timer = 0.0
var paused = false

# === SHIP DATA ===
var ship = {
	"name": "The Kestrel II",
	"hull": 30, "max_hull": 30,
	"shields": 2, "max_shields": 4,
	"power": 8, "max_power": 8,
	"evade": 15,
	"fuel": 16,
	"missiles": 8,
	"drones": 3,
	"scrap": 50,
}


# === SHIP INTERIOR ROOMS ===
# Each room: position on the ship grid, size, system it houses
var ship_rooms = [
	{"name": "pilot", "x": 7, "y": 1, "w": 1, "h": 2, "system": "pilot", "label": "PILOT"},
	{"name": "sensors", "x": 6, "y": 1, "w": 1, "h": 2, "system": "sensors", "label": "SENS"},
	{"name": "doors", "x": 5, "y": 0, "w": 1, "h": 1, "system": "doors", "label": "DOOR"},
	{"name": "medbay", "x": 5, "y": 1, "w": 1, "h": 2, "system": "medbay", "label": "MED"},
	{"name": "o2", "x": 5, "y": 3, "w": 1, "h": 1, "system": "o2", "label": "O2"},
	{"name": "shields", "x": 4, "y": 0, "w": 1, "h": 2, "system": "shields", "label": "SHLD"},
	{"name": "weapons", "x": 4, "y": 2, "w": 1, "h": 2, "system": "weapons", "label": "WEAP"},
	{"name": "engines", "x": 3, "y": 1, "w": 1, "h": 2, "system": "engines", "label": "ENG"},
	{"name": "empty1", "x": 2, "y": 1, "w": 1, "h": 2, "system": "", "label": ""},
	{"name": "teleporter", "x": 1, "y": 1, "w": 1, "h": 2, "system": "teleporter", "label": "TELE"},
]

var enemy_rooms = [
	{"name": "e_pilot", "x": 0, "y": 1, "w": 1, "h": 2, "system": "pilot", "label": "PILOT"},
	{"name": "e_shields", "x": 1, "y": 0, "w": 1, "h": 2, "system": "shields", "label": "SHLD"},
	{"name": "e_weapons", "x": 1, "y": 2, "w": 1, "h": 2, "system": "weapons", "label": "WEAP"},
	{"name": "e_engines", "x": 2, "y": 1, "w": 1, "h": 2, "system": "engines", "label": "ENG"},
	{"name": "e_medbay", "x": 3, "y": 1, "w": 1, "h": 2, "system": "medbay", "label": "MED"},
]

const ROOM_CELL = 38  # pixel size per room grid cell
const PLAYER_SHIP_X = 60
const PLAYER_SHIP_Y = 140
const ENEMY_SHIP_X = 580
const ENEMY_SHIP_Y = 160

var selected_crew = -1  # index of crew being moved
var crew_positions = []  # actual pixel positions for smooth movement

# === SYSTEMS === (level 0 = not installed)
var systems = {
	"shields": {"level": 2, "max": 4, "power": 2, "hp": 2, "max_hp": 2},
	"engines": {"level": 2, "max": 4, "power": 2, "hp": 2, "max_hp": 2},
	"weapons": {"level": 3, "max": 4, "power": 3, "hp": 2, "max_hp": 2},
	"medbay": {"level": 1, "max": 3, "power": 1, "hp": 1, "max_hp": 1},
	"o2": {"level": 1, "max": 3, "power": 1, "hp": 1, "max_hp": 1},
	"pilot": {"level": 1, "max": 3, "power": 0, "hp": 1, "max_hp": 1},
	"sensors": {"level": 1, "max": 3, "power": 1, "hp": 1, "max_hp": 1},
	"doors": {"level": 1, "max": 3, "power": 0, "hp": 1, "max_hp": 1},
	"teleporter": {"level": 0, "max": 3, "power": 0, "hp": 0, "max_hp": 0},
	"cloaking": {"level": 0, "max": 3, "power": 0, "hp": 0, "max_hp": 0},
	"drones_sys": {"level": 0, "max": 3, "power": 0, "hp": 0, "max_hp": 0},
	"hacking": {"level": 0, "max": 3, "power": 0, "hp": 0, "max_hp": 0},
	"mind_ctrl": {"level": 0, "max": 3, "power": 0, "hp": 0, "max_hp": 0},
}

# === WEAPONS ===
# Each weapon: name, damage, shield_pierce, shots, charge_time, power_cost, missile_cost, type
var ALL_WEAPONS = [
	{"name": "Burst Laser I", "dmg": 1, "pierce": 0, "shots": 2, "charge": 10.0, "power": 2, "missile": 0, "type": "laser", "desc": "Fires 2 laser shots"},
	{"name": "Burst Laser II", "dmg": 1, "pierce": 0, "shots": 3, "charge": 12.0, "power": 3, "missile": 0, "type": "laser", "desc": "Fires 3 laser shots"},
	{"name": "Burst Laser III", "dmg": 1, "pierce": 0, "shots": 5, "charge": 16.0, "power": 4, "missile": 0, "type": "laser", "desc": "Fires 5 laser shots"},
	{"name": "Heavy Laser I", "dmg": 2, "pierce": 0, "shots": 1, "charge": 9.0, "power": 1, "missile": 0, "type": "laser", "desc": "1 heavy shot, 2 damage"},
	{"name": "Heavy Laser II", "dmg": 2, "pierce": 0, "shots": 2, "charge": 13.0, "power": 3, "missile": 0, "type": "laser", "desc": "2 heavy shots"},
	{"name": "Pike Beam", "dmg": 1, "pierce": 0, "shots": 1, "charge": 14.0, "power": 2, "missile": 0, "type": "beam", "desc": "Long beam, hits multiple rooms"},
	{"name": "Halberd Beam", "dmg": 2, "pierce": 0, "shots": 1, "charge": 17.0, "power": 3, "missile": 0, "type": "beam", "desc": "Powerful beam, 2 damage"},
	{"name": "Glaive Beam", "dmg": 3, "pierce": 0, "shots": 1, "charge": 21.0, "power": 4, "missile": 0, "type": "beam", "desc": "Devastating 3-damage beam"},
	{"name": "Mini Beam", "dmg": 1, "pierce": 0, "shots": 1, "charge": 8.0, "power": 1, "missile": 0, "type": "beam", "desc": "Small quick beam"},
	{"name": "Leto Missiles", "dmg": 1, "pierce": 1, "shots": 1, "charge": 8.0, "power": 1, "missile": 1, "type": "missile", "desc": "Fast missile, pierces 1 shield"},
	{"name": "Artemis Missiles", "dmg": 2, "pierce": 2, "shots": 1, "charge": 10.0, "power": 1, "missile": 1, "type": "missile", "desc": "Strong missile, pierces shields"},
	{"name": "Hermes Missiles", "dmg": 3, "pierce": 3, "shots": 1, "charge": 14.0, "power": 3, "missile": 1, "type": "missile", "desc": "Heavy missile, pierces all"},
	{"name": "Breach Missile", "dmg": 4, "pierce": 2, "shots": 1, "charge": 18.0, "power": 2, "missile": 1, "type": "missile", "desc": "Massive hull breach"},
	{"name": "Swarm Missiles", "dmg": 1, "pierce": 1, "shots": 3, "charge": 12.0, "power": 2, "missile": 1, "type": "missile", "desc": "3 small homing missiles"},
	{"name": "Ion Blast I", "dmg": 0, "pierce": 0, "shots": 1, "charge": 8.0, "power": 1, "missile": 0, "type": "ion", "desc": "Disables 1 shield layer"},
	{"name": "Ion Blast II", "dmg": 0, "pierce": 0, "shots": 3, "charge": 14.0, "power": 3, "missile": 0, "type": "ion", "desc": "3 ion shots"},
	{"name": "Chain Ion", "dmg": 0, "pierce": 0, "shots": 1, "charge": 14.0, "power": 2, "missile": 0, "type": "ion", "desc": "Gets faster each hit"},
	{"name": "Flak I", "dmg": 1, "pierce": 0, "shots": 3, "charge": 10.0, "power": 2, "missile": 0, "type": "flak", "desc": "3 flak projectiles"},
	{"name": "Flak II", "dmg": 1, "pierce": 0, "shots": 7, "charge": 18.0, "power": 3, "missile": 0, "type": "flak", "desc": "7 flak projectiles"},
	{"name": "Crystal Burst I", "dmg": 1, "pierce": 1, "shots": 2, "charge": 11.0, "power": 2, "missile": 0, "type": "crystal", "desc": "2 crystal shots, pierce 1"},
	{"name": "Vulcan", "dmg": 1, "pierce": 0, "shots": 1, "charge": 11.0, "power": 4, "missile": 0, "type": "laser", "desc": "Gets faster each volley"},
	{"name": "Fire Beam", "dmg": 0, "pierce": 0, "shots": 1, "charge": 14.0, "power": 2, "missile": 0, "type": "fire_beam", "desc": "Sets rooms on fire"},
	{"name": "Anti-Bio Beam", "dmg": 0, "pierce": 0, "shots": 1, "charge": 14.0, "power": 2, "missile": 0, "type": "bio_beam", "desc": "Kills crew, no hull damage"},
	{"name": "Charge Laser", "dmg": 1, "pierce": 0, "shots": 1, "charge": 6.0, "power": 2, "missile": 0, "type": "laser", "desc": "Charges up to 3 shots"},
]

var equipped_weapons = []  # indices into ALL_WEAPONS

# === AUGMENTS ===
var ALL_AUGMENTS = [
	{"name": "Scrap Recovery Arm", "desc": "+10% scrap from all sources", "effect": "scrap_bonus"},
	{"name": "Long-Range Scanners", "desc": "See map node contents", "effect": "scanner"},
	{"name": "Weapon Pre-Igniter", "desc": "Weapons start fully charged", "effect": "pre_ignite"},
	{"name": "Automated Reloader", "desc": "Weapons charge 10% faster", "effect": "reload_bonus"},
	{"name": "Shield Charge Booster", "desc": "Shields recharge faster", "effect": "shield_boost"},
	{"name": "Titanium System Casing", "desc": "15% chance to resist system damage", "effect": "sys_armor"},
	{"name": "Stealth Weapons", "desc": "Firing doesn't break cloak", "effect": "stealth_weap"},
	{"name": "Zoltan Shield", "desc": "Start combat with 5 bonus shield", "effect": "zoltan_shield"},
	{"name": "Drone Recovery Arm", "desc": "Recover drone parts after combat", "effect": "drone_recover"},
	{"name": "Hacking Stun", "desc": "Hacking also stuns crew", "effect": "hack_stun"},
	{"name": "Emergency Respirators", "desc": "Crew takes less suffocation damage", "effect": "respirator"},
	{"name": "Rock Plating", "desc": "Reduce breach chance", "effect": "rock_plate"},
	{"name": "FTL Charge Booster", "desc": "FTL charges 25% faster", "effect": "ftl_boost"},
	{"name": "Backup Battery", "desc": "+2 temporary power in combat", "effect": "backup_bat"},
	{"name": "Distraction Buoys", "desc": "Delayed pursuit on map", "effect": "buoys"},
]
var equipped_augments = []

# === SHIP HANGAR ===
var ALL_SHIPS = [
	{"id": "kestrel", "name": "The Kestrel", "class": "Gunship", "desc": "Balanced loadout. Good for beginners.",
	 "hull": 30, "power": 8, "weapons": [0, 9], "crew_races": [0, 0, 0],
	 "crew_names": ["Isaac", "Nova", "Flux"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 3, "medbay": 1},
	 "augments": [], "color": Color(0.4, 0.45, 0.5)},

	{"id": "stealth", "name": "The Nesasio", "class": "Stealth Cruiser", "desc": "No shields! Start with cloaking and a powerful beam.",
	 "hull": 25, "power": 8, "weapons": [6, 14], "crew_races": [0, 0, 0],
	 "crew_names": ["Shadow", "Ghost", "Wisp"],
	 "systems": {"shields": 0, "engines": 3, "weapons": 3, "cloaking": 2},
	 "augments": [6], "color": Color(0.3, 0.35, 0.45)},

	{"id": "engi", "name": "The Vortex", "class": "Engi Cruiser", "desc": "Ion weapons and drones. Engi crew repairs fast.",
	 "hull": 30, "power": 8, "weapons": [14, 14], "crew_races": [1, 1, 0],
	 "crew_names": ["Virus", "Nano", "Chip"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 2, "drones_sys": 2},
	 "augments": [8], "color": Color(0.3, 0.5, 0.35)},

	{"id": "mantis", "name": "The Gila Monster", "class": "Mantis Cruiser", "desc": "Boarding focused. Mantis crew excels at melee.",
	 "hull": 30, "power": 8, "weapons": [3, 9], "crew_races": [2, 2, 0],
	 "crew_names": ["Fang", "Claw", "Blade"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 2, "teleporter": 2},
	 "augments": [], "color": Color(0.25, 0.5, 0.25)},

	{"id": "rock", "name": "The Bulwark", "class": "Rock Cruiser", "desc": "Heavy hull, missile focused. Rock crew is fire immune.",
	 "hull": 40, "power": 7, "weapons": [10, 11], "crew_races": [3, 3, 0],
	 "crew_names": ["Granite", "Basalt", "Slate"],
	 "systems": {"shields": 2, "engines": 1, "weapons": 3, "medbay": 1},
	 "augments": [11], "color": Color(0.5, 0.4, 0.3)},

	{"id": "zoltan", "name": "The Adjudicator", "class": "Zoltan Cruiser", "desc": "Zoltan crew provides bonus power. Energy shield start.",
	 "hull": 25, "power": 5, "weapons": [3, 0], "crew_races": [4, 4, 4],
	 "crew_names": ["Radiant", "Prism", "Lumen"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 3, "medbay": 1},
	 "augments": [7], "color": Color(0.6, 0.6, 0.25)},

	{"id": "slug", "name": "The Man of War", "class": "Slug Cruiser", "desc": "Hacking and bio weapons. Slug crew has telepathy.",
	 "hull": 28, "power": 8, "weapons": [22, 0], "crew_races": [5, 5, 0],
	 "crew_names": ["Ooze", "Slick", "Murk"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 2, "hacking": 2},
	 "augments": [], "color": Color(0.5, 0.3, 0.5)},

	{"id": "crystal", "name": "The Carnelian", "class": "Crystal Cruiser", "desc": "Crystal weapons pierce shields. Crystal crew has lockdown.",
	 "hull": 30, "power": 8, "weapons": [19, 3], "crew_races": [6, 6, 0],
	 "crew_names": ["Shard", "Facet", "Gem"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 3, "medbay": 1},
	 "augments": [], "color": Color(0.45, 0.35, 0.6)},

	{"id": "lanius", "name": "The Shrike", "class": "Lanius Cruiser", "desc": "Lanius crew drains O2. No need for life support!",
	 "hull": 28, "power": 8, "weapons": [16, 3], "crew_races": [7, 7, 0],
	 "crew_names": ["Rust", "Iron", "Void"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 2, "mind_ctrl": 2},
	 "augments": [10], "color": Color(0.3, 0.3, 0.35)},

	{"id": "heavy", "name": "The Osprey", "class": "Heavy Cruiser", "desc": "Massive hull, 4 weapon slots. Slow but deadly.",
	 "hull": 45, "power": 10, "weapons": [1, 4, 10, 17], "crew_races": [0, 0, 3, 2],
	 "crew_names": ["Tank", "Bull", "Rock", "Spike"],
	 "systems": {"shields": 3, "engines": 1, "weapons": 4, "medbay": 1},
	 "augments": [5], "color": Color(0.45, 0.42, 0.38)},

	{"id": "scout", "name": "The Wasp", "class": "Scout Frigate", "desc": "Fast and evasive. Limited firepower but hard to hit.",
	 "hull": 20, "power": 7, "weapons": [0], "crew_races": [0, 1],
	 "crew_names": ["Zip", "Dart"],
	 "systems": {"shields": 1, "engines": 4, "weapons": 2, "sensors": 2},
	 "augments": [4, 12], "color": Color(0.5, 0.5, 0.3)},

	{"id": "beam", "name": "The Prism", "class": "Beam Frigate", "desc": "All beam weapons. Devastating once shields are down.",
	 "hull": 28, "power": 9, "weapons": [5, 7, 8], "crew_races": [4, 0, 1],
	 "crew_names": ["Ray", "Beam", "Arc"],
	 "systems": {"shields": 2, "engines": 2, "weapons": 4, "medbay": 1},
	 "augments": [3], "color": Color(0.55, 0.45, 0.55)},
]

var hangar_cursor = 0


# === CREW ===
var ALL_RACES = [
	{"name": "Human", "hp": 100, "repair": 1.0, "combat": 1.0, "move": 1.0, "special": "None", "color": Color(0.7, 0.6, 0.5)},
	{"name": "Engi", "hp": 100, "repair": 2.0, "combat": 0.5, "move": 1.0, "special": "Double repair speed", "color": Color(0.3, 0.7, 0.3)},
	{"name": "Mantis", "hp": 100, "repair": 0.5, "combat": 1.5, "move": 1.2, "special": "Melee damage +50%", "color": Color(0.2, 0.7, 0.2)},
	{"name": "Rock", "hp": 150, "repair": 0.5, "combat": 1.0, "move": 0.5, "special": "Fire immune, +50 HP", "color": Color(0.6, 0.4, 0.25)},
	{"name": "Zoltan", "hp": 70, "repair": 1.0, "combat": 0.7, "move": 1.0, "special": "Provides 1 power to room", "color": Color(0.8, 0.8, 0.2)},
	{"name": "Slug", "hp": 100, "repair": 1.0, "combat": 1.0, "move": 1.0, "special": "Telepathy, immune to mind control", "color": Color(0.6, 0.3, 0.6)},
	{"name": "Crystal", "hp": 125, "repair": 1.0, "combat": 1.0, "move": 0.8, "special": "Lockdown ability, reduced suffocation", "color": Color(0.5, 0.4, 0.7)},
	{"name": "Lanius", "hp": 100, "repair": 1.0, "combat": 1.0, "move": 1.0, "special": "Drains O2, immune to suffocation", "color": Color(0.3, 0.3, 0.35)},
]

var crew = []  # list of crew members

# === MAP ===
var sector = 1
var max_sectors = 8
var map_nodes = []
var current_node = 0
var map_visited = {}

# === COMBAT ===
var enemy_ship = {}
var combat_weapons_charge = []
var enemy_weapons_charge = []
var combat_log = []

# === EVENTS ===
var current_event = null

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	frame += 1
	timer += delta
	match state:
		State.TITLE:
			if Input.is_action_just_pressed("click"):
				state = State.HANGAR
				hangar_cursor = 0
		State.HANGAR:
			if Input.is_action_just_pressed("click"):
				_handle_hangar_click()
		State.MAP:
			if Input.is_action_just_pressed("click"):
				_handle_map_click()
		State.COMBAT:
			if not paused:
				_update_combat(delta)
				_update_crew_movement(delta)
			if Input.is_action_just_pressed("pause"):
				paused = not paused
			if Input.is_action_just_pressed("click"):
				_handle_combat_click()
		State.EVENT:
			if Input.is_action_just_pressed("click"):
				_handle_event_click()
		State.GAMEOVER, State.VICTORY:
			if Input.is_action_just_pressed("click"):
				state = State.TITLE
	queue_redraw()

# ================================================================
# GAME SETUP
# ================================================================

func _handle_hangar_click() -> void:
	var mouse = get_global_mouse_position()
	# Ship list on the left
	for i in range(ALL_SHIPS.size()):
		var by = 60 + i * 42
		if mouse.x > 20 and mouse.x < 300 and mouse.y > by - 5 and mouse.y < by + 35:
			hangar_cursor = i
			return
	# Launch button
	if mouse.x > 650 and mouse.x < 850 and mouse.y > 540 and mouse.y < 580:
		_start_game_with_ship(hangar_cursor)

func _start_game_with_ship(ship_idx: int) -> void:
	var s = ALL_SHIPS[ship_idx]
	ship.name = s.name
	ship.hull = s.hull; ship.max_hull = s.hull
	ship.fuel = 16; ship.missiles = 8; ship.drones = 3; ship.scrap = 50
	ship.power = s.power; ship.max_power = s.power
	ship.shields = s.systems.get("shields", 0); ship.evade = 15

	for key in systems:
		systems[key].level = 0; systems[key].power = 0; systems[key].hp = 0; systems[key].max_hp = 0
	for key in s.systems:
		if systems.has(key):
			var lv = s.systems[key]
			systems[key].level = lv; systems[key].power = lv
			systems[key].hp = lv; systems[key].max_hp = lv

	equipped_weapons = s.weapons.duplicate()
	equipped_augments = s.augments.duplicate()

	crew.clear()
	for i in range(s.crew_races.size()):
		var ri = s.crew_races[i]
		var race = ALL_RACES[ri]
		var cname = s.crew_names[i] if i < s.crew_names.size() else "Crew " + str(i)
		crew.append({"name": cname, "race": ri, "hp": race.hp, "max_hp": race.hp,
			"room": ["pilot", "weapons", "engines", "shields"][i % 4],
			"skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})

	sector = 1
	_generate_map()
	_init_crew_positions()
	state = State.MAP

func _start_game() -> void:
	ship.hull = 30; ship.max_hull = 30
	ship.shields = 2; ship.fuel = 16; ship.missiles = 8
	ship.drones = 3; ship.scrap = 50; ship.evade = 15
	ship.power = 8; ship.max_power = 8

	for key in systems:
		systems[key].hp = systems[key].max_hp

	equipped_weapons = [0, 9]  # Burst Laser I + Leto Missiles
	equipped_augments = []

	crew.clear()
	crew.append({"name": "Isaac", "race": 0, "hp": 100, "max_hp": 100, "room": "pilot", "skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})
	crew.append({"name": "Nova", "race": 0, "hp": 100, "max_hp": 100, "room": "weapons", "skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})
	crew.append({"name": "Flux", "race": 1, "hp": 100, "max_hp": 100, "room": "engines", "skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})

	sector = 1
	_generate_map()
	_init_crew_positions()
	state = State.MAP


func _init_crew_positions() -> void:
	crew_positions.clear()
	for c in crew:
		var room = _find_room(c.room)
		if room:
			crew_positions.append(Vector2(
				PLAYER_SHIP_X + (room.x + room.w * 0.5) * ROOM_CELL,
				PLAYER_SHIP_Y + (room.y + room.h * 0.5) * ROOM_CELL))
		else:
			crew_positions.append(Vector2(PLAYER_SHIP_X + 100, PLAYER_SHIP_Y + 60))

func _find_room(room_name: String):
	for r in ship_rooms:
		if r.name == room_name:
			return r
	return null

func _room_at_pixel(px: float, py: float):
	for r in ship_rooms:
		var rx = PLAYER_SHIP_X + r.x * ROOM_CELL
		var ry = PLAYER_SHIP_Y + r.y * ROOM_CELL
		var rw = r.w * ROOM_CELL
		var rh = r.h * ROOM_CELL
		if px >= rx and px < rx + rw and py >= ry and py < ry + rh:
			return r
	return null

func _generate_map() -> void:
	map_nodes.clear()
	map_visited.clear()
	var num_nodes = 12 + sector * 2
	for i in range(num_nodes):
		var node_type = "empty"
		var r = randf()
		if i == 0:
			node_type = "start"
		elif i == num_nodes - 1:
			node_type = "exit"
		elif r < 0.25:
			node_type = "hostile"
		elif r < 0.40:
			node_type = "distress"
		elif r < 0.50:
			node_type = "store"
		elif r < 0.60:
			node_type = "quest"
		elif r < 0.70:
			node_type = "nebula"
		elif r < 0.80:
			node_type = "asteroid"
		else:
			node_type = "empty"

		map_nodes.append({
			"type": node_type,
			"x": 80 + int(float(i) / num_nodes * 780),
			"y": 200 + int(sin(i * 1.7) * 120 + randf() * 60),
			"connections": [],
		})

	# Connect nodes in a rough path
	for i in range(num_nodes - 1):
		map_nodes[i].connections.append(i + 1)
		# Add some branching
		if i + 2 < num_nodes and randf() < 0.4:
			map_nodes[i].connections.append(i + 2)

	current_node = 0
	map_visited[0] = true

# ================================================================
# MAP
# ================================================================
func _handle_map_click() -> void:
	var mouse = get_global_mouse_position()
	var current = map_nodes[current_node]

	for conn in current.connections:
		var node = map_nodes[conn]
		if Vector2(mouse.x, mouse.y).distance_to(Vector2(node.x, node.y)) < 20:
			if ship.fuel <= 0:
				combat_log.append("No fuel!")
				return
			ship.fuel -= 1
			current_node = conn
			map_visited[conn] = true
			_enter_node(conn)
			return

func _enter_node(idx: int) -> void:
	var node = map_nodes[idx]
	match node.type:
		"hostile", "asteroid":
			_start_combat(node.type)
		"store":
			state = State.SHOP
		"exit":
			sector += 1
			if sector > max_sectors:
				state = State.VICTORY
			else:
				_generate_map()
				state = State.MAP
		"distress", "quest", "nebula", "empty", "start":
			_generate_event(node.type)
			state = State.EVENT

# ================================================================
# EVENTS
# ================================================================
var ALL_EVENTS = [
	{"text": "You find a damaged space station. Survivors hail you.", "choices": [
		{"text": "Help them (lose 2 fuel)", "result": "You rescue 3 survivors. +15 scrap.", "scrap": 15, "fuel": -2},
		{"text": "Ignore and move on", "result": "You leave them behind.", "scrap": 0, "fuel": 0},
		{"text": "Loot the station", "result": "You find supplies! +25 scrap, but your reputation suffers.", "scrap": 25, "fuel": 0},
	]},
	{"text": "A merchant ship offers to trade.", "choices": [
		{"text": "Buy fuel (10 scrap)", "result": "+3 fuel", "scrap": -10, "fuel": 3},
		{"text": "Buy missiles (8 scrap)", "result": "+2 missiles", "scrap": -8, "fuel": 0, "missiles": 2},
		{"text": "Decline", "result": "You continue on your way.", "scrap": 0, "fuel": 0},
	]},
	{"text": "You encounter a debris field from a recent battle.", "choices": [
		{"text": "Search the wreckage", "result": "You find useful salvage! +20 scrap", "scrap": 20, "fuel": 0},
		{"text": "Too risky, move on", "result": "Better safe than sorry.", "scrap": 0, "fuel": 0},
	]},
	{"text": "An allied ship is under attack! They request assistance.", "choices": [
		{"text": "Help them fight", "result": "Together you defeat the enemy! +30 scrap, +1 crew member", "scrap": 30, "fuel": 0, "add_crew": true},
		{"text": "It's not your fight", "result": "You watch them get destroyed...", "scrap": 0, "fuel": 0},
	]},
	{"text": "You detect an energy anomaly nearby.", "choices": [
		{"text": "Investigate", "result": "It's a cache of supplies! +2 fuel, +15 scrap", "scrap": 15, "fuel": 2},
		{"text": "Avoid it", "result": "You steer clear.", "scrap": 0, "fuel": 0},
		{"text": "Scan it (requires sensors)", "result": "Your sensors reveal it's a trap! +5 scrap for the intel.", "scrap": 5, "fuel": 0},
	]},
	{"text": "A pirate offers you a deal: pay 20 scrap or fight.", "choices": [
		{"text": "Pay the toll", "result": "You pay 20 scrap and pass safely.", "scrap": -20, "fuel": 0},
		{"text": "Fight!", "result": "Battle stations!", "scrap": 0, "fuel": 0, "fight": true},
	]},
	{"text": "You find an abandoned research station.", "choices": [
		{"text": "Explore carefully", "result": "You find experimental weapons data! +1 weapon power", "scrap": 10, "fuel": 0},
		{"text": "Salvage for parts", "result": "+15 scrap and +3 hull repair", "scrap": 15, "fuel": 0, "hull": 3},
		{"text": "Leave it alone", "result": "You don't trust it.", "scrap": 0, "fuel": 0},
	]},
	{"text": "A nebula storm is disrupting your sensors.", "choices": [
		{"text": "Push through", "result": "You take minor damage but find scrap. -5 hull, +20 scrap", "scrap": 20, "fuel": 0, "hull": -5},
		{"text": "Go around (costs fuel)", "result": "Safe but slow. -2 fuel", "scrap": 0, "fuel": -2},
	]},
	{"text": "You intercept a distress signal from a luxury liner.", "choices": [
		{"text": "Rescue passengers", "result": "Grateful passengers reward you! +40 scrap", "scrap": 40, "fuel": -1},
		{"text": "Board and loot", "result": "You take everything. +60 scrap, -1 crew morale", "scrap": 60, "fuel": 0},
		{"text": "Ignore", "result": "Not your problem.", "scrap": 0, "fuel": 0},
	]},
	{"text": "A Zoltan peace envoy requests passage.", "choices": [
		{"text": "Welcome aboard", "result": "A Zoltan crew member joins! They provide extra power.", "scrap": 0, "fuel": 0, "add_crew_race": 4},
		{"text": "No room, sorry", "result": "They understand and leave.", "scrap": 10, "fuel": 0},
	]},
]

var event_choice_made = false

func _generate_event(node_type: String) -> void:
	current_event = ALL_EVENTS[randi() % ALL_EVENTS.size()].duplicate(true)
	event_choice_made = false

func _handle_event_click() -> void:
	if event_choice_made:
		state = State.MAP
		return

	var mouse = get_global_mouse_position()
	if current_event == null:
		state = State.MAP
		return

	for i in range(current_event.choices.size()):
		var by = 300 + i * 50
		if mouse.x > 200 and mouse.x < 760 and mouse.y > by - 15 and mouse.y < by + 25:
			var choice = current_event.choices[i]
			current_event["result_text"] = choice.result
			ship.scrap += choice.get("scrap", 0)
			ship.fuel += choice.get("fuel", 0)
			ship.missiles += choice.get("missiles", 0)
			ship.hull += choice.get("hull", 0)
			ship.hull = mini(ship.hull, ship.max_hull)

			if choice.get("add_crew", false):
				var race_idx = randi() % ALL_RACES.size()
				var names = ["Zara", "Rex", "Kira", "Bolt", "Shade", "Ember", "Frost", "Spark"]
				crew.append({"name": names[randi() % names.size()], "race": race_idx, "hp": ALL_RACES[race_idx].hp, "max_hp": ALL_RACES[race_idx].hp, "room": "medbay", "skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})

			if choice.get("add_crew_race", -1) >= 0:
				var ri = choice.add_crew_race
				crew.append({"name": "Envoy", "race": ri, "hp": ALL_RACES[ri].hp, "max_hp": ALL_RACES[ri].hp, "room": "pilot", "skills": {"pilot": 0, "engines": 0, "shields": 0, "weapons": 0, "combat": 0, "repair": 0}})

			if choice.get("fight", false):
				_start_combat("hostile")
				return

			event_choice_made = true
			return

# ================================================================
# COMBAT
# ================================================================

func _handle_combat_click() -> void:
	var mouse = get_global_mouse_position()

	# Check if clicking on a crew member to select
	for i in range(crew.size()):
		if i >= crew_positions.size(): break
		if crew[i].hp <= 0: continue
		var cp = crew_positions[i]
		if Vector2(mouse.x, mouse.y).distance_to(cp) < 14:
			if selected_crew == i:
				selected_crew = -1  # deselect
			else:
				selected_crew = i
			return

	# If crew is selected, click a room to move them there
	if selected_crew >= 0:
		var room = _room_at_pixel(mouse.x, mouse.y)
		if room:
			crew[selected_crew].room = room.name
			# Set target position
			var target = Vector2(
				PLAYER_SHIP_X + (room.x + room.w * 0.5) * ROOM_CELL,
				PLAYER_SHIP_Y + (room.y + room.h * 0.5) * ROOM_CELL)
			# Offset so crew don't stack
			var offset_idx = 0
			for j in range(crew.size()):
				if j != selected_crew and crew[j].room == room.name:
					offset_idx += 1
			target.x += (offset_idx % 2) * 12 - 6
			target.y += (offset_idx / 2) * 12 - 6
			crew[selected_crew]["target"] = target
			selected_crew = -1
			return

	selected_crew = -1

func _update_crew_movement(delta: float) -> void:
	for i in range(crew.size()):
		if i >= crew_positions.size(): continue
		if crew[i].hp <= 0: continue
		var target = crew[i].get("target")
		if target == null:
			# If no explicit target, move toward their assigned room
			var room = _find_room(crew[i].room)
			if room:
				target = Vector2(
					PLAYER_SHIP_X + (room.x + room.w * 0.5) * ROOM_CELL,
					PLAYER_SHIP_Y + (room.y + room.h * 0.5) * ROOM_CELL)
		if target != null:
			var speed = 60.0 * ALL_RACES[crew[i].race].move
			var dir = target - crew_positions[i]
			if dir.length() > 2:
				crew_positions[i] += dir.normalized() * speed * delta
			else:
				crew_positions[i] = target
				crew[i].erase("target")

func _start_combat(combat_type: String) -> void:
	# Generate enemy ship
	var difficulty = sector + randf() * 2
	enemy_ship = {
		"name": ["Rebel Fighter", "Pirate Scout", "Auto-Scout", "Rebel Rigger", "Slug Interceptor", "Mantis Bomber", "Rock Assault", "Crystal Sentinel"][randi() % 8],
		"hull": int(10 + difficulty * 5),
		"max_hull": int(10 + difficulty * 5),
		"shields": mini(int(difficulty * 0.7), 4),
		"evade": int(10 + difficulty * 3),
		"weapons": [],
		"charge": [],
	}

	# Give enemy weapons based on difficulty
	var num_weaps = 1 + int(difficulty * 0.5)
	for i in range(mini(num_weaps, 4)):
		var widx = randi() % ALL_WEAPONS.size()
		enemy_ship.weapons.append(widx)
		enemy_ship.charge.append(0.0)

	# Init player weapon charges
	combat_weapons_charge.clear()
	for w in equipped_weapons:
		combat_weapons_charge.append(0.0)

	combat_log.clear()
	combat_log.append("Combat started vs " + enemy_ship.name + "!")
	_init_crew_positions()
	paused = true
	state = State.COMBAT

func _update_combat(delta: float) -> void:
	# Charge player weapons
	for i in range(equipped_weapons.size()):
		var w = ALL_WEAPONS[equipped_weapons[i]]
		if combat_weapons_charge[i] < w.charge:
			combat_weapons_charge[i] += delta
		elif combat_weapons_charge[i] >= w.charge:
			# Auto-fire when charged
			_fire_weapon(i)
			combat_weapons_charge[i] = 0.0

	# Charge enemy weapons
	for i in range(enemy_ship.weapons.size()):
		var w = ALL_WEAPONS[enemy_ship.weapons[i]]
		if enemy_ship.charge[i] < w.charge:
			enemy_ship.charge[i] += delta
		elif enemy_ship.charge[i] >= w.charge:
			_enemy_fire(i)
			enemy_ship.charge[i] = 0.0

	# Shield recharge
	if ship.shields < systems.shields.level and frame % 120 == 0:
		ship.shields += 1

	# Check win/lose
	if enemy_ship.hull <= 0:
		var scrap_reward = 20 + sector * 10 + randi() % 15
		ship.scrap += scrap_reward
		combat_log.append("Enemy destroyed! +" + str(scrap_reward) + " scrap")
		state = State.MAP
	if ship.hull <= 0:
		state = State.GAMEOVER

func _fire_weapon(idx: int) -> void:
	var w = ALL_WEAPONS[equipped_weapons[idx]]
	if w.missile > 0:
		if ship.missiles <= 0:
			return
		ship.missiles -= w.missile

	var total_dmg = 0
	for s in range(w.shots):
		# Evasion check
		if randi() % 100 < enemy_ship.evade:
			combat_log.append(w.name + " missed!")
			continue

		var dmg = w.dmg
		if w.type == "ion":
			if enemy_ship.shields > 0:
				enemy_ship.shields -= 1
				combat_log.append(w.name + " ionized shield!")
			continue

		# Shield absorption
		var effective_shields = maxi(0, enemy_ship.shields - w.pierce)
		if effective_shields > 0 and w.type != "beam":
			enemy_ship.shields = maxi(0, enemy_ship.shields - 1)
			combat_log.append(w.name + " absorbed by shields")
			continue

		enemy_ship.hull -= dmg
		total_dmg += dmg

	if total_dmg > 0:
		combat_log.append(w.name + " hit for " + str(total_dmg) + " damage!")

func _enemy_fire(idx: int) -> void:
	var w = ALL_WEAPONS[enemy_ship.weapons[idx]]

	for s in range(w.shots):
		if randi() % 100 < ship.evade:
			combat_log.append("Enemy " + w.name + " missed!")
			continue

		var dmg = w.dmg
		if w.type == "ion":
			if ship.shields > 0:
				ship.shields -= 1
			continue

		var eff_shields = maxi(0, ship.shields - w.pierce)
		if eff_shields > 0 and w.type != "beam":
			ship.shields = maxi(0, ship.shields - 1)
			combat_log.append("Shields absorbed enemy fire")
			continue

		ship.hull -= dmg
		combat_log.append("Enemy hit for " + str(dmg) + " damage! Hull: " + str(ship.hull))

# ================================================================
# DRAWING
# ================================================================
func _draw() -> void:
	match state:
		State.TITLE: _draw_title()
		State.HANGAR: _draw_hangar()
		State.MAP: _draw_map()
		State.COMBAT: _draw_combat()
		State.EVENT: _draw_event()
		State.GAMEOVER: _draw_gameover()
		State.VICTORY: _draw_victory()


func _draw_hangar() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.04, 0.05, 0.08))
	for i in range(60):
		draw_rect(Rect2(fmod(i*137.5, float(SW)), fmod(i*91.3, float(SH)), 1, 1), Color(0.3, 0.4, 0.5, 0.2))

	_text(350, 35, "SHIP HANGAR", 22, Color(0.7, 0.8, 0.9))
	_text(340, 55, "Choose your vessel", 10, Color(0.5, 0.5, 0.6))

	# Ship list
	for i in range(ALL_SHIPS.size()):
		var s = ALL_SHIPS[i]
		var by = 60 + i * 42
		var selected = i == hangar_cursor
		var bg = Color(0.12, 0.14, 0.2) if not selected else Color(0.18, 0.22, 0.32)
		draw_rect(Rect2(20, by - 5, 280, 38), bg)
		if selected:
			draw_rect(Rect2(20, by - 5, 280, 38), Color(0.3, 0.6, 0.9, 0.4), false, 2)
		draw_rect(Rect2(24, by + 2, 8, 24), s.color)
		_text(38, by + 14, s.name, 9, Color(0.85, 0.88, 0.92) if selected else Color(0.6, 0.63, 0.68))
		_text(38, by + 28, s.get("class", ""), 7, s.color * 1.2)

	# Selected ship details
	if hangar_cursor >= 0 and hangar_cursor < ALL_SHIPS.size():
		var s = ALL_SHIPS[hangar_cursor]
		var dx = 330
		var dy = 80

		# Ship preview box
		draw_rect(Rect2(dx, dy, 600, 440), Color(0.06, 0.07, 0.10))
		draw_rect(Rect2(dx, dy, 600, 440), Color(0.2, 0.3, 0.4, 0.4), false, 1)

		_text(dx + 20, dy + 30, s.name, 18, Color(0.8, 0.85, 0.95))
		_text(dx + 20, dy + 50, s.get("class", ""), 11, s.color * 1.3)
		_text(dx + 20, dy + 75, s.desc, 10, Color(0.6, 0.65, 0.72))

		# Ship visual
		_draw_hangar_ship(dx + 300, dy + 180, s)

		# Stats
		_text(dx + 20, dy + 120, "STATS", 10, Color(0.6, 0.7, 0.8))
		_text(dx + 20, dy + 140, "Hull: " + str(s.hull), 9, Color(0.7, 0.5, 0.3))
		_text(dx + 20, dy + 158, "Power: " + str(s.power), 9, Color(0.8, 0.8, 0.3))
		_text(dx + 120, dy + 140, "Shields: " + str(s.systems.get("shields", 0)), 9, Color(0.3, 0.6, 0.9))
		_text(dx + 120, dy + 158, "Engines: " + str(s.systems.get("engines", 0)), 9, Color(0.5, 0.7, 0.5))

		# Weapons
		_text(dx + 20, dy + 190, "WEAPONS", 10, Color(0.6, 0.7, 0.8))
		for wi in range(s.weapons.size()):
			var w = ALL_WEAPONS[s.weapons[wi]]
			_text(dx + 20, dy + 210 + wi * 18, "- " + w.name, 8, Color(0.7, 0.65, 0.55))
			_text(dx + 200, dy + 210 + wi * 18, w.desc, 7, Color(0.5, 0.5, 0.55))

		# Crew
		_text(dx + 20, dy + 300, "CREW", 10, Color(0.6, 0.7, 0.8))
		for ci in range(s.crew_races.size()):
			var ri = s.crew_races[ci]
			var race = ALL_RACES[ri]
			var cname = s.crew_names[ci] if ci < s.crew_names.size() else "Crew"
			_text(dx + 20, dy + 320 + ci * 16, cname + " (" + race.name + ")", 8, race.color)
			_text(dx + 180, dy + 320 + ci * 16, race.special, 7, Color(0.5, 0.5, 0.55))

		# Augments
		if s.augments.size() > 0:
			_text(dx + 20, dy + 400, "AUGMENTS", 10, Color(0.6, 0.7, 0.8))
			for ai in range(s.augments.size()):
				var aug = ALL_AUGMENTS[s.augments[ai]]
				_text(dx + 20, dy + 418 + ai * 14, aug.name + " - " + aug.desc, 7, Color(0.6, 0.7, 0.5))

	# Launch button
	draw_rect(Rect2(650, 540, 200, 40), Color(0.15, 0.3, 0.15))
	draw_rect(Rect2(650, 540, 200, 40), Color(0.3, 0.7, 0.3), false, 2)
	_text(700, 566, "LAUNCH", 16, Color(0.5, 1.0, 0.5))

func _draw_hangar_ship(x: float, y: float, s: Dictionary) -> void:
	var c = s.color
	# Ship body
	draw_rect(Rect2(x - 50, y - 18, 100, 36), c * 0.7)
	draw_rect(Rect2(x - 46, y - 14, 92, 28), c)
	draw_rect(Rect2(x - 42, y - 10, 84, 20), c * 1.2)
	# Nose
	var nose = PackedVector2Array([Vector2(x + 50, y - 12), Vector2(x + 72, y), Vector2(x + 50, y + 12)])
	draw_colored_polygon(nose, c)
	# Wings
	draw_rect(Rect2(x - 35, y - 35, 50, 10), c * 0.6)
	draw_rect(Rect2(x - 35, y + 25, 50, 10), c * 0.6)
	# Engines
	draw_circle(Vector2(x - 52, y - 6), 5, Color(0.3, 0.6, 0.9, 0.6))
	draw_circle(Vector2(x - 52, y + 6), 5, Color(0.3, 0.6, 0.9, 0.6))
	# Cockpit
	draw_rect(Rect2(x + 25, y - 6, 14, 12), Color(0.2, 0.6, 0.8, 0.5))
	# Shield bubble
	var shield_lv = s.systems.get("shields", 0)
	for si in range(shield_lv):
		draw_arc(Vector2(x, y), 60 + si * 10, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.1 + si * 0.03), 1)

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.02, 0.03, 0.06))
	for i in range(150):
		var sx = fmod(i * 97.5 + timer * (1 + i%3), float(SW))
		var sy = fmod(i * 63.3, float(SH))
		draw_rect(Rect2(sx, sy, 1, 1), Color(0.5, 0.6, 0.8, 0.2 + sin(timer + i) * 0.15))
	_text(280, 220, "FTFTL", 48, Color(0.6, 0.8, 1.0))
	_text(240, 270, "Faster Than Faster Than Light", 16, Color(0.5, 0.6, 0.7))
	_text(300, 320, "More weapons. More ships.", 12, Color(0.4, 0.5, 0.6))
	_text(300, 340, "More crew. More events.", 12, Color(0.4, 0.5, 0.6))
	_text(300, 360, "More augments. More everything.", 12, Color(0.4, 0.5, 0.6))
	if fmod(timer, 1.0) < 0.6:
		_text(370, 450, "CLICK TO START", 16, Color.WHITE)

func _draw_map() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.03, 0.04, 0.08))
	# Stars
	for i in range(80):
		draw_rect(Rect2(fmod(i*137.5, float(SW)), fmod(i*91.3, float(SH)), 1, 1), Color(0.4, 0.5, 0.6, 0.3))

	_text(30, 30, "SECTOR " + str(sector) + " / " + str(max_sectors), 16, Color(0.7, 0.8, 0.9))
	_text(30, 55, ship.name, 12, Color(0.5, 0.6, 0.7))

	# Draw connections
	for i in range(map_nodes.size()):
		var node = map_nodes[i]
		for conn in node.connections:
			var target = map_nodes[conn]
			draw_line(Vector2(node.x, node.y), Vector2(target.x, target.y), Color(0.2, 0.3, 0.4, 0.5), 1)

	# Draw nodes
	for i in range(map_nodes.size()):
		var node = map_nodes[i]
		var is_current = i == current_node
		var is_reachable = i in map_nodes[current_node].connections
		var visited = map_visited.has(i)

		var color = Color(0.3, 0.3, 0.4)
		match node.type:
			"hostile": color = Color(0.8, 0.2, 0.2)
			"distress": color = Color(0.2, 0.6, 0.8)
			"store": color = Color(0.2, 0.8, 0.2)
			"quest": color = Color(0.8, 0.8, 0.2)
			"exit": color = Color(0.8, 0.6, 0.2)
			"nebula": color = Color(0.5, 0.3, 0.7)
			"asteroid": color = Color(0.6, 0.5, 0.3)

		if is_current:
			draw_circle(Vector2(node.x, node.y), 14, Color(0.3, 0.7, 1.0, 0.3))

		var alpha = 1.0 if (is_reachable or is_current) else 0.4
		draw_circle(Vector2(node.x, node.y), 8, Color(color.r, color.g, color.b, alpha))
		if is_current:
			draw_circle(Vector2(node.x, node.y), 10, Color(1, 1, 1, 0.5), false, 2)

		if is_reachable and not visited:
			_text(node.x - 20, node.y + 22, node.type, 7, Color(0.6, 0.6, 0.7))

	# Ship info panel
	_draw_ship_info(30, 450)

func _draw_combat() -> void:
	# Space background
	draw_rect(Rect2(0, 0, SW, SH), Color(0.02, 0.02, 0.06))
	for i in range(80):
		var sx = fmod(i * 97.5 + timer * 2, float(SW))
		var sy = fmod(i * 63.3, float(SH))
		draw_rect(Rect2(sx, sy, 1, 1), Color(0.4, 0.5, 0.6, 0.2 + sin(timer + i) * 0.1))

	# === PLAYER SHIP INTERIOR ===
	_draw_ship_interior(PLAYER_SHIP_X, PLAYER_SHIP_Y, ship_rooms, true)

	# === ENEMY SHIP INTERIOR ===
	_draw_ship_interior(ENEMY_SHIP_X, ENEMY_SHIP_Y, enemy_rooms, false)

	# === CREW MEMBERS on player ship ===
	for i in range(crew.size()):
		if i >= crew_positions.size(): break
		if crew[i].hp <= 0: continue
		var cp = crew_positions[i]
		var race = ALL_RACES[crew[i].race]
		var selected = i == selected_crew

		# Selection ring
		if selected:
			draw_circle(cp, 12, Color(0.3, 0.8, 1.0, 0.3))
			draw_circle(cp, 10, Color(0.3, 0.8, 1.0, 0.15))

		# Crew body
		draw_circle(cp, 7, race.color * 0.7)
		draw_circle(Vector2(cp.x, cp.y - 1), 6, race.color)
		# Head
		draw_circle(Vector2(cp.x, cp.y - 6), 4, race.color * 1.2)
		# Eyes
		draw_rect(Rect2(cp.x - 2, cp.y - 7, 1, 1), Color(0.9, 0.9, 0.9))
		draw_rect(Rect2(cp.x + 1, cp.y - 7, 1, 1), Color(0.9, 0.9, 0.9))
		# Name tag
		_text(cp.x - 10, cp.y + 14, crew[i].name, 6, race.color * 1.3)
		# HP bar
		var hp_frac = float(crew[i].hp) / crew[i].max_hp
		draw_rect(Rect2(cp.x - 8, cp.y + 16, 16, 2), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(cp.x - 8, cp.y + 16, 16 * hp_frac, 2), Color(0.2, 0.8, 0.3) if hp_frac > 0.3 else Color(0.9, 0.2, 0.1))

	# Shield bubble around player ship
	if ship.shields > 0:
		var cx = PLAYER_SHIP_X + 4 * ROOM_CELL / 2
		var cy = PLAYER_SHIP_Y + 2 * ROOM_CELL
		for si in range(ship.shields):
			draw_arc(Vector2(cx, cy), 90 + si * 12, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.12 + si * 0.04), 2)

	# Shield bubble around enemy
	if enemy_ship.shields > 0:
		var ecx = ENEMY_SHIP_X + 2.5 * ROOM_CELL
		var ecy = ENEMY_SHIP_Y + 2 * ROOM_CELL
		for si in range(enemy_ship.shields):
			draw_arc(Vector2(ecx, ecy), 70 + si * 10, 0, TAU, 32, Color(0.8, 0.3, 0.2, 0.12 + si * 0.04), 2)

	# "VS" label
	_text(440, 200, "VS", 18, Color(0.5, 0.5, 0.6, 0.5))

	# Weapon charge bars
	_text(30, 500, "WEAPONS:", 10, Color(0.7, 0.7, 0.8))
	for i in range(equipped_weapons.size()):
		var w = ALL_WEAPONS[equipped_weapons[i]]
		var charge_frac = combat_weapons_charge[i] / w.charge if w.charge > 0 else 0
		var by = 520 + i * 28
		draw_rect(Rect2(30, by, 200, 18), Color(0.1, 0.1, 0.15))
		draw_rect(Rect2(30, by, 200 * charge_frac, 18), Color(0.2, 0.6, 0.3) if charge_frac < 1.0 else Color(0.3, 0.9, 0.4))
		_text(35, by + 13, w.name, 8, Color.WHITE)
		if charge_frac >= 1.0:
			_text(180, by + 13, "READY", 8, Color(0.3, 1.0, 0.4))

	# Enemy info
	_text(600, 500, enemy_ship.name, 12, Color(0.8, 0.4, 0.3))
	_text(600, 520, "Hull: " + str(enemy_ship.hull) + "/" + str(enemy_ship.max_hull), 10, Color(0.7, 0.7, 0.7))
	_text(600, 540, "Shields: " + str(enemy_ship.shields), 10, Color(0.3, 0.6, 0.9))

	# Ship info
	_draw_ship_info(300, 500)

	# Combat log
	draw_rect(Rect2(350, 30, 260, 200), Color(0, 0, 0, 0.5))
	_text(360, 48, "COMBAT LOG", 9, Color(0.6, 0.6, 0.7))
	var log_start = maxi(0, combat_log.size() - 8)
	for i in range(log_start, combat_log.size()):
		_text(360, 65 + (i - log_start) * 16, combat_log[i], 7, Color(0.7, 0.7, 0.7))

	# Pause indicator
	if paused:
		_text(420, 280, "PAUSED", 20, Color(1, 1, 1, 0.5 + sin(timer * 3) * 0.3))
		_text(380, 310, "Press SPACE to unpause", 10, Color(0.6, 0.6, 0.7))

func _draw_event() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.04, 0.05, 0.08))
	for i in range(40):
		draw_rect(Rect2(fmod(i*137.5, float(SW)), fmod(i*63.3, float(SH)), 1, 1), Color(0.3, 0.4, 0.5, 0.2))

	if current_event == null:
		return

	# Event box
	draw_rect(Rect2(150, 100, 660, 420), Color(0.08, 0.09, 0.14))
	draw_rect(Rect2(150, 100, 660, 420), Color(0.3, 0.4, 0.5), false, 2)

	_text(180, 140, "EVENT", 14, Color(0.7, 0.8, 0.9))
	_text(180, 180, current_event.text, 11, Color(0.8, 0.8, 0.85))

	if event_choice_made:
		_text(200, 300, current_event.get("result_text", ""), 11, Color(0.5, 0.8, 0.5))
		_text(350, 460, "Click to continue", 10, Color(0.6, 0.6, 0.7))
	else:
		for i in range(current_event.choices.size()):
			var choice = current_event.choices[i]
			var by = 300 + i * 50
			var mouse = get_global_mouse_position()
			var hovered = mouse.x > 200 and mouse.x < 760 and mouse.y > by - 15 and mouse.y < by + 25
			draw_rect(Rect2(200, by - 15, 560, 38), Color(0.12, 0.15, 0.22) if not hovered else Color(0.18, 0.22, 0.32))
			draw_rect(Rect2(200, by - 15, 560, 38), Color(0.3, 0.4, 0.5, 0.5), false, 1)
			_text(215, by + 8, str(i + 1) + ". " + choice.text, 10, Color(0.8, 0.85, 0.9) if not hovered else Color(1, 1, 1))

func _draw_ship_info(x: float, y: float) -> void:
	draw_rect(Rect2(x, y, 250, 140), Color(0, 0, 0, 0.4))
	_text(x + 5, y + 16, "Hull: " + str(ship.hull) + "/" + str(ship.max_hull), 9, Color(0.8, 0.5, 0.3))
	var hull_frac = float(ship.hull) / ship.max_hull
	draw_rect(Rect2(x + 60, y + 7, 100, 10), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(x + 60, y + 7, 100 * hull_frac, 10), Color(0.2, 0.8, 0.3) if hull_frac > 0.3 else Color(0.9, 0.2, 0.1))

	_text(x + 5, y + 34, "Shields: " + str(ship.shields), 8, Color(0.3, 0.6, 0.9))
	_text(x + 5, y + 50, "Fuel: " + str(ship.fuel), 8, Color(0.7, 0.5, 0.2))
	_text(x + 5, y + 66, "Missiles: " + str(ship.missiles), 8, Color(0.8, 0.3, 0.2))
	_text(x + 5, y + 82, "Scrap: " + str(ship.scrap), 8, Color(0.8, 0.8, 0.3))
	_text(x + 5, y + 98, "Crew: " + str(crew.size()), 8, Color(0.6, 0.7, 0.6))

	# Crew list
	for i in range(mini(crew.size(), 4)):
		var c = crew[i]
		var race = ALL_RACES[c.race]
		_text(x + 130, y + 34 + i * 16, c.name + " (" + race.name + ")", 7, race.color)


func _draw_ship_interior(ox: float, oy: float, rooms: Array, is_player: bool) -> void:
	var hull_color = Color(0.22, 0.24, 0.28) if is_player else Color(0.28, 0.20, 0.18)
	var wall_color = Color(0.35, 0.38, 0.42) if is_player else Color(0.42, 0.30, 0.25)
	var floor_color = Color(0.15, 0.16, 0.20) if is_player else Color(0.20, 0.14, 0.12)

	# Draw hull outline (slightly larger than rooms)
	var min_x = 999; var min_y = 999; var max_x = 0; var max_y = 0
	for r in rooms:
		min_x = mini(min_x, r.x)
		min_y = mini(min_y, r.y)
		max_x = maxi(max_x, r.x + r.w)
		max_y = maxi(max_y, r.y + r.h)

	var hull_rect = Rect2(ox + min_x * ROOM_CELL - 4, oy + min_y * ROOM_CELL - 4,
		(max_x - min_x) * ROOM_CELL + 8, (max_y - min_y) * ROOM_CELL + 8)
	draw_rect(hull_rect, hull_color)
	draw_rect(Rect2(hull_rect.position.x + 2, hull_rect.position.y + 2,
		hull_rect.size.x - 4, hull_rect.size.y - 4), floor_color)

	# Draw each room
	for r in rooms:
		var rx = ox + r.x * ROOM_CELL
		var ry = oy + r.y * ROOM_CELL
		var rw = r.w * ROOM_CELL
		var rh = r.h * ROOM_CELL

		# Room floor
		draw_rect(Rect2(rx + 1, ry + 1, rw - 2, rh - 2), floor_color)

		# Room walls
		draw_rect(Rect2(rx, ry, rw, rh), wall_color, false, 2)

		# System color tint based on what's in the room
		var sys = r.get("system", "")
		var tint = Color(0, 0, 0, 0)
		match sys:
			"shields": tint = Color(0.1, 0.2, 0.5, 0.15)
			"weapons": tint = Color(0.5, 0.2, 0.1, 0.15)
			"engines": tint = Color(0.2, 0.4, 0.2, 0.15)
			"medbay": tint = Color(0.1, 0.4, 0.1, 0.2)
			"pilot": tint = Color(0.3, 0.3, 0.1, 0.15)
			"o2": tint = Color(0.1, 0.3, 0.4, 0.15)
			"teleporter": tint = Color(0.4, 0.2, 0.4, 0.15)
			"cloaking": tint = Color(0.2, 0.2, 0.3, 0.15)
			"sensors": tint = Color(0.3, 0.3, 0.2, 0.15)
			"drones_sys": tint = Color(0.3, 0.25, 0.1, 0.15)
			"hacking": tint = Color(0.3, 0.1, 0.3, 0.15)
			"mind_ctrl": tint = Color(0.4, 0.1, 0.2, 0.15)

		if tint.a > 0:
			draw_rect(Rect2(rx + 2, ry + 2, rw - 4, rh - 4), tint)

		# System icon/label
		if r.label != "":
			_text(rx + 3, ry + rh - 4, r.label, 6, wall_color * 0.8)

		# System level pips (if player ship)
		if is_player and sys != "" and systems.has(sys):
			var lv = systems[sys].level
			for pip in range(lv):
				draw_rect(Rect2(rx + 3 + pip * 6, ry + 3, 4, 4), Color(0.3, 0.7, 0.3))

		# Room furniture/details
		match sys:
			"pilot":
				# Chair and console
				draw_rect(Rect2(rx + rw/2 - 4, ry + 4, 8, 6), Color(0.3, 0.3, 0.35))
				draw_rect(Rect2(rx + rw/2 - 3, ry + 12, 6, 4), Color(0.25, 0.25, 0.3))
			"weapons":
				# Weapon racks
				for wi in range(mini(equipped_weapons.size() if is_player else 2, 3)):
					draw_rect(Rect2(rx + 4 + wi * 10, ry + 4, 8, 3), Color(0.4, 0.3, 0.2))
			"shields":
				# Shield generator
				draw_circle(Vector2(rx + rw/2, ry + rh/2), 8, Color(0.15, 0.25, 0.45, 0.5))
				draw_circle(Vector2(rx + rw/2, ry + rh/2), 5, Color(0.2, 0.35, 0.6, 0.4))
			"engines":
				# Engine pipes
				draw_rect(Rect2(rx + 2, ry + rh/2 - 3, rw - 4, 6), Color(0.25, 0.25, 0.22))
				draw_rect(Rect2(rx + 3, ry + rh/2 - 2, rw - 6, 4), Color(0.3, 0.3, 0.25))
			"medbay":
				# Med cross
				draw_rect(Rect2(rx + rw/2 - 1, ry + rh/2 - 5, 3, 10), Color(0.2, 0.5, 0.2, 0.4))
				draw_rect(Rect2(rx + rw/2 - 4, ry + rh/2 - 1, 9, 3), Color(0.2, 0.5, 0.2, 0.4))
			"teleporter":
				# Teleporter pad
				draw_circle(Vector2(rx + rw/2, ry + rh/2), 10, Color(0.35, 0.2, 0.45, 0.3))
				draw_circle(Vector2(rx + rw/2, ry + rh/2), 6, Color(0.45, 0.25, 0.55, 0.2))

	# Ship name
	var name_text = ship.name if is_player else enemy_ship.get("name", "Enemy")
	_text(ox + min_x * ROOM_CELL, oy + min_y * ROOM_CELL - 16, name_text, 9,
		Color(0.6, 0.7, 0.8) if is_player else Color(0.8, 0.5, 0.4))

func _draw_ship_sprite(x: float, y: float, s: Dictionary, is_player: bool) -> void:
	# Ship body
	var body_color = Color(0.4, 0.45, 0.5) if is_player else Color(0.5, 0.3, 0.25)
	var light_color = body_color * 1.3
	var dark_color = body_color * 0.6

	# Hull
	draw_rect(Rect2(x - 40, y - 15, 80, 30), dark_color)
	draw_rect(Rect2(x - 38, y - 13, 76, 26), body_color)
	draw_rect(Rect2(x - 35, y - 10, 70, 20), light_color)

	# Nose
	var nose_pts = PackedVector2Array([
		Vector2(x + 40, y - 10), Vector2(x + 60, y), Vector2(x + 40, y + 10)])
	draw_colored_polygon(nose_pts, body_color)

	# Wings
	draw_rect(Rect2(x - 30, y - 30, 40, 8), dark_color)
	draw_rect(Rect2(x - 30, y + 22, 40, 8), dark_color)

	# Engine glow
	if is_player:
		draw_circle(Vector2(x - 42, y), 6, Color(0.2, 0.5, 0.9, 0.5))
		draw_circle(Vector2(x - 42, y), 4, Color(0.4, 0.7, 1.0, 0.7))
	else:
		draw_circle(Vector2(x - 42, y), 6, Color(0.8, 0.3, 0.1, 0.5))

	# Cockpit
	draw_rect(Rect2(x + 20, y - 5, 12, 10), Color(0.2, 0.6, 0.8, 0.6))

	# Shield bubble
	if s.has("shields") and s.shields > 0:
		for si in range(s.shields):
			draw_arc(Vector2(x, y), 50 + si * 8, 0, TAU, 32, Color(0.3, 0.6, 1.0, 0.15 + si * 0.05), 2)

	# Hull bar
	var max_h = s.get("max_hull", 30)
	var cur_h = s.get("hull", 30)
	var frac = float(cur_h) / max_h if max_h > 0 else 0
	draw_rect(Rect2(x - 30, y + 40, 60, 6), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(x - 30, y + 40, 60 * frac, 6), Color(0.2, 0.8, 0.3) if frac > 0.3 else Color(0.9, 0.2, 0.1))

func _draw_gameover() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.02, 0.02, 0.04))
	_text(350, 250, "SHIP DESTROYED", 28, Color(0.8, 0.2, 0.2))
	_text(340, 300, "Sector " + str(sector) + " / " + str(max_sectors), 14, Color(0.6, 0.6, 0.7))
	_text(370, 400, "Click to restart", 12, Color(0.5, 0.5, 0.6))

func _draw_victory() -> void:
	draw_rect(Rect2(0, 0, SW, SH), Color(0.02, 0.04, 0.06))
	_text(350, 250, "VICTORY!", 36, Color(0.3, 0.9, 0.4))
	_text(300, 300, "You delivered the data across " + str(max_sectors) + " sectors!", 12, Color(0.6, 0.7, 0.8))
	_text(370, 400, "Click to play again", 12, Color(0.5, 0.5, 0.6))

func _text(x: float, y: float, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
