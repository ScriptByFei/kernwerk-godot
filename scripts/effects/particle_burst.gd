class_name ParticleBurst
extends Node2D
## Kleine, kurzlebige CPU-Partikelbursts fuer Gameplay-Feedback.

# Zentraler Tuning-Punkt fuer alle Burst-Varianten.
const MIN_INITIAL_VELOCITY := 60.0
const MAX_INITIAL_VELOCITY := 120.0
const SPREAD_DEGREES := 180.0
const GRAVITY := Vector2(0.0, 120.0)
const PARTICLE_SIZE := 6
const PARTICLE_SCALE := 1.0

static var _texture: ImageTexture

static func burst(world: Node2D, at: Vector2, color: Color, count: int = 10, lifetime: float = 0.35) -> void:
	if world == null:
		return

	var particles := CPUParticles2D.new()
	particles.name = "ParticleBurst"
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = lifetime
	particles.direction = Vector2.UP
	particles.spread = SPREAD_DEGREES
	particles.gravity = GRAVITY
	particles.initial_velocity_min = MIN_INITIAL_VELOCITY
	particles.initial_velocity_max = MAX_INITIAL_VELOCITY
	particles.scale_amount_min = PARTICLE_SCALE
	particles.scale_amount_max = PARTICLE_SCALE
	particles.scale_amount_curve = _scale_curve()
	particles.color = color
	particles.texture = _particle_texture()
	particles.finished.connect(particles.queue_free)
	world.add_child(particles)
	particles.global_position = at
	particles.emitting = true

static func _particle_texture() -> ImageTexture:
	if _texture:
		return _texture
	var image := Image.create(PARTICLE_SIZE, PARTICLE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_texture = ImageTexture.create_from_image(image)
	return _texture

static func _scale_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
