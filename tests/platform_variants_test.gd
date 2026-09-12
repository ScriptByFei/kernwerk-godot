extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var probe := JumpPlatform.new()
	if not probe.has_method("configure_variant"):
		_check(false, "platform variants are implemented")
		probe.free()
		_finish()
		return
	probe.free()
	for seed_value in range(12):
		var world := Node2D.new()
		root.add_child(world)
		var director := PlatformDirector.new(seed_value)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		for p in director._active_platforms:
			_check(p.get("variant") == 0, "initial ledges remain standard")
		var seen := {}
		var replay := []
		for step in range(40):
			director.maintain(-step * 350.0, -step * 350.0 + 1920.0, step % 6)
			for p in director._active_platforms:
				seen[p.get("variant")] = true
				var shape: RectangleShape2D = p.get_child(0).shape
				_check(shape.size == p.platform_size, "renderer and collider dimensions match")
				_check(p.position.x - p.platform_size.x * 0.5 >= 0.0 and p.position.x + p.platform_size.x * 0.5 <= 1080.0, "full platform stays inside shaft")
			replay.append(_snapshot(director))
			_check(director.active_platform_count <= JumpConfig.MAX_ACTIVE_PLATFORMS, "bounded population")
		# Vier Varianten seit Phase 5: Standard, schmal, Resonanzfokus und die
		# riskante Abzweigung der Routenwahl.
		for expected_variant in [0, 1, 2]:
			_check(seen.has(expected_variant), "route variant %d occurs" % expected_variant)
		director.initialize(world, JumpConfig.PLATFORM_LAYOUT)
		for step in range(40):
			director.maintain(-step * 350.0, -step * 350.0 + 1920.0, step % 6)
			_check(replay[step] == _snapshot(director), "seed replay includes variant and width")
		world.free()
	var normal := JumpPlatform.new()
	var focus := JumpPlatform.new()
	focus.call("configure_variant", 2)
	_check(normal.call("classify_contact", 120.0) == JumpConfig.LandingQuality.NORMAL, "standard outside resonance band is NORMAL")
	_check(focus.call("classify_contact", 120.0) == JumpConfig.LandingQuality.RESONANCE, "focus widens actual resonance classification")
	_check(focus.call("resonance_band_width") > normal.call("resonance_band_width"), "visible focus band matches wider classifier")
	_check(focus.call("classify_contact", 67.2) == normal.call("classify_contact", 67.2), "PERFECT band unchanged")
	normal.free()
	focus.free()
	# Conservative worst-case base bounce, no resonance: accelerate, steer and
	# brake from rest at every supported tick rate; hit the narrow ledge centre.
	for fps in [30, 60, 120]:
		for side in [-1.0, 1.0]:
			var jumper := Jumper.new()
			jumper.position = Vector2(540.0, 0.0)
			jumper.velocity = Vector2(0.0, -JumpConfig.BASE_BOUNCE_SPEED)
			jumper.set_horizontal_target(540.0 + side * 380.0)
			var dt := 1.0 / float(fps)
			var crossed := false
			for tick in range(fps * 2):
				var previous_y := jumper.position.y
				jumper.apply_gravity(dt)
				jumper.apply_horizontal_steering(dt)
				jumper.position += jumper.velocity * dt
				if jumper.velocity.y > 0.0 and previous_y <= -350.0 and jumper.position.y >= -350.0:
					crossed = true
					_check(absf(jumper.position.x - jumper.horizontal_target_x) < 62.0, "worst-case narrow landing has full-body margin at %d FPS" % fps)
					break
			_check(crossed, "base bounce reaches maximum gap")
			jumper.free()
	_finish()

func _snapshot(director: PlatformDirector) -> Array:
	var result := []
	for p in director._active_platforms:
		result.append([p.position, p.get("variant"), p.platform_size])
	return result

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _finish() -> void:
	print("PLATFORM VARIANTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
