class_name SkyBackground
extends RefCounted

## SkyBackground: Fröhliche, lebendige Himmels- und Wolkenwelt für den Endless Jumper.
## Bietet 5 fließend ineinander übergehende Höhenzonen:
## 1. Sonniger Sommerhimmel (0.0 .. 1.0)
## 2. Wolkenmeer & Heißluftballons (1.0 .. 2.0)
## 3. Goldene Höhe & Sonnenkrone (2.0 .. 3.0)
## 4. Zauberhafte Dämmerung & Sternenstaub (3.0 .. 4.0)
## 5. Kosmische Aurora & Sternenglanz (4.0+)

const JumpConfig = preload("res://scripts/jump/jump_config.gd")

static var _rng := RandomNumberGenerator.new()

const SKY_THEMES := [
	# Zone 1: Sonniger Sommerhimmel
	{
		"sky_top": Color("47a0ff"),
		"sky_bottom": Color("b2e3ff"),
		"cloud_body": Color("ffffff"),
		"cloud_shadow": Color("d2e5f8"),
		"cloud_glow": Color(1.0, 1.0, 1.0, 0.45),
		"ray_color": Color(1.0, 0.98, 0.82, 0.10),
		"has_balloons": true,
		"has_stars": false,
		"has_aurora": false
	},
	# Zone 2: Wolkenmeer & Pastellhimmel
	{
		"sky_top": Color("52c7ea"),
		"sky_bottom": Color("d5f5fc"),
		"cloud_body": Color("fffefb"),
		"cloud_shadow": Color("fae0e8"),
		"cloud_glow": Color(1.0, 0.96, 0.92, 0.40),
		"ray_color": Color(1.0, 0.95, 0.88, 0.08),
		"has_balloons": true,
		"has_stars": false,
		"has_aurora": false
	},
	# Zone 3: Goldene Höhe & Sonnenkrone
	{
		"sky_top": Color("f59624"),
		"sky_bottom": Color("fedd82"),
		"cloud_body": Color("fffaf0"),
		"cloud_shadow": Color("f6c79a"),
		"cloud_glow": Color(1.0, 0.94, 0.75, 0.50),
		"ray_color": Color(1.0, 0.92, 0.65, 0.16),
		"has_balloons": true,
		"has_stars": false,
		"has_aurora": false
	},
	# Zone 4: Zauberhafte Dämmerung & Sternenstaub
	{
		"sky_top": Color("4f3b78"),
		"sky_bottom": Color("9f6e98"),
		"cloud_body": Color("e6d4ec"),
		"cloud_shadow": Color("68476e"),
		"cloud_glow": Color(1.0, 0.90, 0.98, 0.40),
		"ray_color": Color(0.9, 0.8, 1.0, 0.06),
		"has_balloons": false,
		"has_stars": true,
		"has_aurora": false
	},
	# Zone 5: Kosmische Aurora & Sternenglanz
	{
		"sky_top": Color("111630"),
		"sky_bottom": Color("1e2a52"),
		"cloud_body": Color("353c66"),
		"cloud_shadow": Color("1a1f36"),
		"cloud_glow": Color(0.55, 0.90, 0.85, 0.35),
		"ray_color": Color(0.5, 0.95, 0.85, 0.06),
		"has_balloons": false,
		"has_stars": true,
		"has_aurora": true
	}
]

static func get_theme(zone_idx: float) -> Dictionary:
	var clamped := clampf(zone_idx, 0.0, float(SKY_THEMES.size() - 1))
	var base_idx := int(floor(clamped))
	var next_idx := mini(base_idx + 1, SKY_THEMES.size() - 1)
	var frac := clamped - float(base_idx)
	
	var t0: Dictionary = SKY_THEMES[base_idx]
	var t1: Dictionary = SKY_THEMES[next_idx]
	
	return {
		"sky_top": (t0.sky_top as Color).lerp(t1.sky_top, frac),
		"sky_bottom": (t0.sky_bottom as Color).lerp(t1.sky_bottom, frac),
		"cloud_body": (t0.cloud_body as Color).lerp(t1.cloud_body, frac),
		"cloud_shadow": (t0.cloud_shadow as Color).lerp(t1.cloud_shadow, frac),
		"cloud_glow": (t0.cloud_glow as Color).lerp(t1.cloud_glow, frac),
		"ray_color": (t0.ray_color as Color).lerp(t1.ray_color, frac),
		"has_balloons": t0.has_balloons if frac < 0.5 else t1.has_balloons,
		"has_stars": t0.has_stars if frac < 0.5 else t1.has_stars,
		"has_aurora": t0.has_aurora if frac < 0.5 else t1.has_aurora,
	}

static func draw(canvas: CanvasItem, rect: Rect2, zone_idx: float, time: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
		
	var theme := get_theme(zone_idx)
	
	# 1. Himmelsverlauf
	_draw_sky_gradient(canvas, rect, theme.sky_top, theme.sky_bottom)
	
	# 2. Kosmische Aurora (Zone 5)
	if theme.has_aurora:
		_draw_aurora(canvas, rect, time)
		
	# 3. Sternenstaub & Glitzern (Zone 4 & 5)
	if theme.has_stars:
		_draw_stars(canvas, rect, time)
		
	# 4. Sonnenstrahlen (God Rays)
	if (theme.ray_color as Color).a > 0.01:
		_draw_sun_rays(canvas, rect, theme.ray_color)
		
	# 5. Wolkenschichten mit Parallaxe
	# Fern-Wolkenbank (langsamer Drift, etwas transparenter)
	_draw_cloud_layer(canvas, rect, 0.16, 560.0, theme.cloud_body, theme.cloud_shadow, theme.cloud_glow, 101, 130.0, 180.0, 0.88)
	# Haupt-Wolkenbank (Nah)
	_draw_cloud_layer(canvas, rect, 0.38, 820.0, theme.cloud_body, theme.cloud_shadow, theme.cloud_glow, 203, 160.0, 220.0, 1.0)
	
	# 6. Schwebende bunte Ballons (Zone 1..3)
	if theme.has_balloons:
		_draw_balloons(canvas, rect, time, zone_idx)

static func _draw_sky_gradient(canvas: CanvasItem, rect: Rect2, top_col: Color, bot_col: Color) -> void:
	var steps := 28
	var step_h := rect.size.y / float(steps)
	for s in range(steps):
		var y := rect.position.y + float(s) * step_h
		var t := float(s) / float(steps - 1)
		var c := top_col.lerp(bot_col, t)
		canvas.draw_rect(Rect2(rect.position.x, y, rect.size.x, step_h + 1.5), c)

static func _draw_sun_rays(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var sun_origin := Vector2(rect.get_center().x - 40.0, rect.position.y - 100.0)
	var ray_angles := [-0.48, -0.24, 0.02, 0.26, 0.50]
	var ray_widths := [110.0, 150.0, 130.0, 160.0, 120.0]
	var length := rect.size.y * 1.5
	
	for i in range(ray_angles.size()):
		var angle: float = ray_angles[i]
		var width: float = ray_widths[i]
		var dir := Vector2(sin(angle), cos(angle))
		var perp := Vector2(-dir.y, dir.x)
		var p1 := sun_origin + dir * 50.0 - perp * (width * 0.12)
		var p2 := sun_origin + dir * 50.0 + perp * (width * 0.12)
		var p3 := sun_origin + dir * length + perp * width
		var p4 := sun_origin + dir * length - perp * width
		canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), color)

static func _draw_cloud_layer(canvas: CanvasItem, rect: Rect2, parallax: float, span: float,
		c_body: Color, c_shadow: Color, c_glow: Color, seed_offset: int, r_min: float, r_max: float, alpha_scale: float) -> void:
	var camera_y := rect.get_center().y
	var base_y := camera_y * parallax
	var first_idx := int(floor((rect.position.y - base_y) / span))
	var last_idx := int(ceil((rect.end.y - base_y) / span))
	
	var body := Color(c_body.r, c_body.g, c_body.b, c_body.a * alpha_scale)
	var shadow := Color(c_shadow.r, c_shadow.g, c_shadow.b, c_shadow.a * alpha_scale)
	var glow := Color(c_glow.r, c_glow.g, c_glow.b, c_glow.a * alpha_scale)
	
	for n in range(first_idx, last_idx + 1):
		var y := base_y + float(n) * span
		_rng.seed = hash(n * 1337 + seed_offset)
		
		# Wolke links (flankt den Schacht)
		var lx := rect.position.x + _rng.randf_range(-10.0, 60.0)
		var lr := _rng.randf_range(r_min, r_max)
		_draw_single_cloud(canvas, Vector2(lx, y + _rng.randf_range(-40.0, 40.0)), lr, body, shadow, glow, _rng)
		
		# Wolke rechts (flankt den Schacht)
		var rx := rect.end.x - _rng.randf_range(-10.0, 60.0)
		var rr := _rng.randf_range(r_min, r_max)
		_draw_single_cloud(canvas, Vector2(rx, y + _rng.randf_range(-40.0, 40.0)), rr, body, shadow, glow, _rng)

static func _draw_single_cloud(canvas: CanvasItem, center: Vector2, radius: float,
		body_col: Color, shadow_col: Color, glow_col: Color, rng: RandomNumberGenerator) -> void:
	var offsets := [
		Vector2.ZERO,
		Vector2(-radius * 0.44, radius * 0.12),
		Vector2(radius * 0.44, radius * 0.12),
		Vector2(-radius * 0.22, -radius * 0.32),
		Vector2(radius * 0.22, -radius * 0.32),
		Vector2(0.0, -radius * 0.42),
		Vector2(-radius * 0.60, radius * 0.24),
		Vector2(radius * 0.60, radius * 0.24)
	]
	var radii := [
		radius * 0.74,
		radius * 0.58,
		radius * 0.58,
		radius * 0.54,
		radius * 0.54,
		radius * 0.62,
		radius * 0.44,
		radius * 0.44
	]
	
	# 1. Schattenbasis
	var s_off := Vector2(0.0, radius * 0.13)
	for i in range(offsets.size()):
		canvas.draw_circle(center + offsets[i] + s_off, radii[i], shadow_col)
		
	# 2. Wolkenkörper
	for i in range(offsets.size()):
		canvas.draw_circle(center + offsets[i], radii[i], body_col)
		
	# 3. Zarte Glanzkante oben
	if glow_col.a > 0.01:
		for i in range(3, 6):
			canvas.draw_circle(center + offsets[i] + Vector2(0.0, -radii[i] * 0.14), radii[i] * 0.86, glow_col)

static func _draw_balloons(canvas: CanvasItem, rect: Rect2, time: float, zone_idx: float) -> void:
	var colors := [
		Color("ff5252"), Color("ff793f"), Color("ffb142"),
		Color("33d9b2"), Color("34ace0"), Color("706fd3")
	]
	
	var base_positions := [
		Vector2(rect.position.x + 190.0, rect.position.y + 420.0),
		Vector2(rect.position.x + 230.0, rect.position.y + 450.0),
		Vector2(rect.end.x - 210.0, rect.position.y + 280.0),
		Vector2(rect.end.x - 250.0, rect.position.y + 310.0),
		Vector2(rect.position.x + 240.0, rect.position.y + 880.0),
		Vector2(rect.end.x - 200.0, rect.position.y + 760.0),
	]
	
	for i in range(base_positions.size()):
		var base: Vector2 = base_positions[i]
		var col: Color = colors[i % colors.size()]
		var rad := 15.0 + float(i % 3) * 2.5
		var speed := 0.9 + float(i) * 0.15
		var sway := sin(time * speed + float(i) * 1.7) * 10.0
		var pos := Vector2(base.x + sway, base.y - fmod(time * 24.0 * speed, rect.size.y + 200.0) + 100.0)
		
		# Schnur
		var s_start := pos + Vector2(0.0, rad * 1.1)
		var s_end := s_start + Vector2(-sway * 0.35, rad * 2.2)
		canvas.draw_line(s_start, s_end, Color(0.75, 0.75, 0.75, 0.55), 1.5)
		
		# Ballon
		canvas.draw_circle(pos, rad, col)
		canvas.draw_circle(s_start, rad * 0.18, col.darkened(0.25))
		canvas.draw_circle(pos + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.25, Color(1.0, 1.0, 1.0, 0.75))

static func _draw_stars(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	_rng.seed = 998877
	for i in range(45):
		var sx := rect.position.x + _rng.randf_range(140.0, rect.size.x - 140.0)
		var sy := rect.position.y + _rng.randf_range(40.0, rect.size.y - 40.0)
		var twinkle := (sin(time * 3.0 + float(i) * 2.1) + 1.0) * 0.5
		var alpha := 0.25 + twinkle * 0.65
		var s_rad := 1.5 + twinkle * 1.5
		canvas.draw_circle(Vector2(sx, sy), s_rad, Color(1.0, 1.0, 0.85, alpha))

static func _draw_aurora(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	var bands := 3
	var aurora_colors := [
		Color(0.2, 0.95, 0.65, 0.12),
		Color(0.3, 0.75, 0.98, 0.10),
		Color(0.85, 0.35, 0.90, 0.08)
	]
	for b in range(bands):
		var pts: Array[Vector2] = []
		var pts_rev: Array[Vector2] = []
		var base_y: float = rect.position.y + 120.0 + float(b) * 110.0
		var h: float = 70.0 + float(b) * 25.0
		var col: Color = aurora_colors[b]
		
		var segments := 16
		for s in range(segments + 1):
			var x := rect.position.x + float(s) * (rect.size.x / float(segments))
			var wave := sin(time * 1.2 + float(s) * 0.6 + float(b) * 1.5) * 45.0
			var y1 := base_y + wave
			var y2 := y1 + h
			pts.append(Vector2(x, y1))
			pts_rev.insert(0, Vector2(x, y2))
			
		pts.append_array(pts_rev)
		canvas.draw_colored_polygon(PackedVector2Array(pts), col)
