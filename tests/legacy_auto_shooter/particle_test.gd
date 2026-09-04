extends SceneTree
## Phase-8.3-Tests: einmalige, kurzlebige CPU-Partikelbursts.

const ParticleBurstScript = preload("res://scripts/effects/particle_burst.gd")

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	await process_frame

	var color := Color(0.2, 0.8, 1.0)
	ParticleBurstScript.burst(world, Vector2(32.0, 48.0), color, 7, 0.2)
	var first := _bursts(world)
	_check(first.size() == 1, "burst erzeugt genau ein CPUParticles2D-Child")
	if not first.is_empty():
		var particles := first[0] as CPUParticles2D
		_check(particles.emitting and particles.amount == 7, "Burst emittiert mit geforderter Partikelanzahl")
		_check(particles.color == color, "Burst uebernimmt die angeforderte Farbe")

	ParticleBurstScript.burst(world, Vector2(64.0, 48.0), Color(0.4, 1.0, 0.55), 9, 0.2)
	_check(_bursts(world).size() == 2, "Zwei aufeinanderfolgende Bursts bleiben getrennte Nodes")

	await create_timer(1.5).timeout
	_check(_bursts(world).is_empty(), "One-shot-Partikel werden nach finished freigegeben")

	if fails == 0:
		print("PARTICLE TESTS: ALLE OK")
	else:
		print("PARTICLE TESTS: %d FEHLER" % fails)
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)

func _bursts(world: Node2D) -> Array[CPUParticles2D]:
	var out: Array[CPUParticles2D] = []
	for child in world.get_children():
		if child is CPUParticles2D:
			out.append(child)
	return out
