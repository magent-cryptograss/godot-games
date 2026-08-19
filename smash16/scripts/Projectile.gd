extends Node2D
class_name Shot

# ---------------------------------------------------------------------------
# A PROJECTILE
#
# Note the variable is called `shooter`, not `owner` -- Node already has an
# `owner` property and shadowing it causes very confusing bugs.
# ---------------------------------------------------------------------------

var shooter = null
var arena = null
var kind: String = ""
var shot_name: String = ""
var data: Dictionary = {}

var vel := Vector2.ZERO
var dir: int = 1
var life: int = 60
var age: int = 0
var bounces_left: int = 0
var radius: float = 3.0
var charge_t: float = 0.0
var still: bool = false
var hit_reg: Dictionary = {}

# combat values, already scaled by charge
var dmg: float = 0.0
var bkb: float = 0.0
var kbg: float = 0.0
var ang: float = 0.0
var multi: int = 0

var dead: bool = false


func setup(from, name: String, charge_ratio: float) -> void:
	shooter = from
	shot_name = name
	data = Moves.SHOTS[name]
	kind = String(data.get("kind", "energy"))
	charge_t = clampf(charge_ratio, 0.0, 1.0)
	dir = from.facing
	still = bool(data.get("still", false))
	multi = int(data.get("multi", 0))
	bounces_left = int(data.get("bounces", 0))
	life = int(data["life"])

	# A fully charged shot is bigger, faster, and hurts a great deal more.
	var boost := 1.0 + 2.4 * charge_t
	radius = float(data["r"]) * (1.0 + 0.85 * charge_t)
	dmg = float(data["dmg"]) * boost * float(from.ch["power"])
	bkb = float(data["bkb"]) * (1.0 + 0.85 * charge_t)
	kbg = float(data["kbg"]) * (1.0 + 0.35 * charge_t)
	ang = float(data["ang"])

	var sp := 1.0 + 0.30 * charge_t
	vel = Vector2(float(data["vx"]) * dir * sp, float(data["vy"]))

	var sc: float = float(from.ch["size"])
	position = from.position + Vector2(7.0 * sc * dir, -13.0 * sc)
	z_index = 12


func as_move() -> Dictionary:
	# Projectiles reuse the exact same hit resolution as melee moves.
	var d := {"dmg": dmg, "bkb": bkb, "kbg": kbg, "ang": ang, "w": radius * 2.0,
			  "h": radius * 2.0, "oy": 0.0}
	if multi > 0:
		d["multi"] = multi
	return d


func rect() -> Rect2:
	return Rect2(position.x - radius, position.y - radius, radius * 2.0, radius * 2.0)


func tick(fighters: Array) -> void:
	age += 1
	life -= 1

	if not still:
		# boomerang turns around partway out and comes home
		if data.has("returns") and age == int(data["returns"]):
			vel.x = -vel.x
			Sfx.play("shot")
		vel.y += float(data["grav"])
		position += vel

		# bounce off the top of the stage
		var s: Rect2 = Rules.SOLID
		if vel.y > 0.0 and position.y + radius >= s.position.y \
		   and position.y + radius <= s.position.y + 10.0 \
		   and position.x > s.position.x and position.x < s.position.x + s.size.x:
			if bounces_left > 0:
				bounces_left -= 1
				position.y = s.position.y - radius
				vel.y = -absf(vel.y) * 0.78
				Sfx.play("bounce")
			else:
				_burst()
				dead = true
				return

	# --- hit detection ---
	var r := rect()
	for f in fighters:
		if f == shooter or f.ko_timer > 0 or f.invuln > 0:
			continue
		if multi > 0:
			var last := int(hit_reg.get(f, -999))
			if age - last < multi:
				continue
		elif hit_reg.has(f):
			continue
		if r.intersects(f.hurtbox()):
			hit_reg[f] = age
			if arena:
				arena.resolve_hit(shooter, f, as_move(), position)
			if multi <= 0:
				_burst()
				dead = true
				return

	if life <= 0 or position.x < -40.0 or position.x > Rules.VW + 40.0 \
	   or position.y > Rules.VH + 60.0 or position.y < -80.0:
		dead = true
		return

	queue_redraw()


func _burst() -> void:
	# PK Fire leaves a pillar behind when it connects.
	if data.has("burst") and arena:
		arena.spawn_burst(shooter, String(data["burst"]), position)


func _draw() -> void:
	var pal: Dictionary = shooter.ch["pal"] if shooter else {}
	var accent: Color = pal.get("accent", Color("ffffff"))
	var flick := 1.0 + sin(float(age) * 0.9) * 0.12

	match kind:
		"energy":
			var core := Color(1, 1, 1, 0.95)
			Art.disc(self, 0, 0, radius * 1.35 * flick, Color(accent.r, accent.g, accent.b, 0.35))
			Art.disc(self, 0, 0, radius, accent)
			Art.disc(self, 0, 0, maxf(1.0, radius * 0.45), core)
			# a short speed trail
			Art.px(self, -vel.x * 1.2, -1, absf(vel.x) * 1.2, 2,
				Color(accent.r, accent.g, accent.b, 0.30))
		"fire":
			Art.disc(self, 0, 0, radius * 1.3 * flick, Color("ff8c1a"))
			Art.disc(self, 0, 0, radius * 0.85, Color("ffd23f"))
			Art.disc(self, 0, -radius * 0.2, radius * 0.4, Color(1, 1, 1, 0.9))
		"pillar":
			# a tall column of flame
			var h := radius * 3.2
			for i in range(6):
				var t := float(i) / 5.0
				var w := radius * (1.0 - t * 0.55) * (1.0 + sin(float(age) * 0.7 + t * 4.0) * 0.18)
				var c := Color("ff8c1a").lerp(Color("ffe680"), t)
				c.a = 0.9 - t * 0.35
				Art.px(self, -w, -h * t - radius, w * 2.0, h / 5.0 + 1.0, c)
		"boomerang":
			var a := float(age) * 0.55
			var arm := radius * 1.7
			Art.limb(self, Vector2(cos(a) * arm, sin(a) * arm * 0.6),
				Vector2(-cos(a) * arm, -sin(a) * arm * 0.6), 2.4,
				Color("d8a838"), Color("3a2a10"))
			Art.limb(self, Vector2(cos(a + 1.6) * arm * 0.7, sin(a + 1.6) * arm * 0.45),
				Vector2(-cos(a + 1.6) * arm * 0.7, -sin(a + 1.6) * arm * 0.45), 2.2,
				Color("f0e0b0"), Color("3a2a10"))
		"egg":
			Art.disc(self, 0, 0, radius + 1.0, Color("2a5a20"))
			Art.disc(self, 0, 0, radius, Color("f4f4e8"))
			Art.disc(self, 0, radius * 0.25, radius * 0.85, Color("ffffff"))
			Art.px(self, -radius * 0.7, -radius * 0.2, 2, 2, Color("46c83c"))
			Art.px(self, radius * 0.2, radius * 0.35, 2, 2, Color("46c83c"))
			Art.px(self, -radius * 0.1, -radius * 0.75, 2, 2, Color("46c83c"))
		_:
			Art.disc(self, 0, 0, radius, accent)
