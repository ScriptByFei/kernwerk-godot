class_name Jumper
extends CharacterBody2D

const REACTOR_IDLE_FRAMES := preload("res://assets/jump/reactor_core/reactor_idle_frames.tres")
const REACTOR_JUMP_FRAMES := preload("res://assets/jump/reactor_core/reactor_jump_frames.tres")
const REACTOR_LAND_FRAMES := preload("res://assets/jump/reactor_core/reactor_land_frames.tres")

signal bounced
signal landed(platform: JumpPlatform, quality: JumpConfig.LandingQuality, bonus: int)

var horizontal_intent := 0.0
var horizontal_target_x := 0.0
var has_horizontal_target := false

var _reactor_visual: AnimatedSprite2D
var _bounce_sequence: Array[StringName] = []
var last_landing_quality := JumpConfig.LandingQuality.NORMAL
var landing_count := 0
var _contact_latched := false
var _impact_remaining := 0.0
var _feedback_visual: Node2D
## Resonanzstand 0.0 .. 1.0, nur fuer die Ringintensitaet. Die Ladungen selbst
## liegen im ResonanceSystem, damit es genau eine Quelle der Wahrheit gibt.
var _resonance_ratio := 0.0
var _overload_remaining := 0.0
## Dive-Zustand. `_dive_available` wird bei JEDEM Absprung neu gesetzt (einmal
## pro Sprung), `_dive_active` bei der Landung geloescht.
var _dive_active := false
var _dive_available := false
## Zaehlt ausgeloeste Dives. Nur fuer QA — ohne diesen Zaehler laesst sich
## "hoechstens einmal je Sprung" von aussen nicht belegen.
var dive_count := 0

func charge_light_alpha() -> float:
	if _overload_remaining > 0.0:
		return JumpConfig.OVERLOAD_LIGHT_ALPHA * (_overload_remaining / JumpConfig.RESONANCE_OVERLOAD_DISPLAY_TIME)
	return JumpConfig.CHARGE_LIGHT_ALPHAS[_held_charges()]

func charge_light_radius() -> float:
	if _overload_remaining > 0.0:
		return JumpConfig.OVERLOAD_LIGHT_RADIUS
	return JumpConfig.CHARGE_LIGHT_RADIUS[_held_charges()]

## Ladungsstand fuer die Darstellung. `_resonance_ratio` kommt aus dem Spiel und
## ist genau charges / max_charges; daraus laesst sich der Index zurueckrechnen,
## ohne dass der Jumper eine zweite Quelle der Wahrheit fuehrt.
func _held_charges() -> int:
	var maximum := JumpConfig.RESONANCE_MAX_CHARGES
	if maximum <= 1:
		return 0
	return clampi(roundi(_resonance_ratio * float(maximum)), 0, maximum - 1)

func charge_light_strength() -> float:
	return charge_light_alpha()

func is_overloaded() -> bool:
	return _overload_remaining > 0.0

## Wird unmittelbar vor dem Absprung befragt: bekommt die Landequalitaet und
## meldet, ob dieser Absprung ueberladen ist. Das Spiel haengt hier das
## ResonanceSystem ein, damit die Overload-Kraft im selben Tick wirkt.
var overload_check: Callable

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = JumpConfig.JUMPER_SIZE
	collision.shape = shape
	add_child(collision)
	_create_reactor_visual()
	_feedback_visual = Node2D.new()
	_feedback_visual.name = "CoreContactLight"
	add_child(_feedback_visual)
	_feedback_visual.draw.connect(_draw_contact_light)

func _create_reactor_visual() -> void:
	_reactor_visual = AnimatedSprite2D.new()
	_reactor_visual.name = "ReactorVisual"
	_reactor_visual.sprite_frames = REACTOR_IDLE_FRAMES
	_reactor_visual.animation = &"idle"
	_reactor_visual.autoplay = &"idle"
	_reactor_visual.centered = false
	_reactor_visual.position = JumpConfig.REACTOR_VISUAL_POSITION
	_reactor_visual.scale = JumpConfig.REACTOR_VISUAL_SCALE
	_reactor_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_reactor_visual)
	_reactor_visual.play()

func _process(delta: float) -> void:
	if _overload_remaining > 0.0:
		_overload_remaining = maxf(0.0, _overload_remaining - delta)
		_feedback_visual.queue_redraw()
	if _impact_remaining > 0.0:
		_impact_remaining = maxf(0.0, _impact_remaining - delta)
		_feedback_visual.queue_redraw()
	if _reactor_visual.is_playing():
		return
	_play_next_bounce_animation()

func _play_next_bounce_animation() -> void:
	if _reactor_visual == null:
		return
	if _bounce_sequence.is_empty():
		_reactor_visual.sprite_frames = REACTOR_IDLE_FRAMES
		_reactor_visual.animation = &"idle"
		_reactor_visual.speed_scale = 1.0
		_reactor_visual.play()
		return
	var anim: StringName = _bounce_sequence.pop_front()
	_reactor_visual.sprite_frames = _frames_for(anim)
	_reactor_visual.animation = anim
	_reactor_visual.speed_scale = JumpConfig.LAND_ANIMATION_SPEED if anim == &"land" else JumpConfig.JUMP_ANIMATION_SPEED
	_reactor_visual.play()

func _frames_for(anim: StringName) -> SpriteFrames:
	match anim:
		&"jump":
			return REACTOR_JUMP_FRAMES
		&"land":
			return REACTOR_LAND_FRAMES
		_:
			return REACTOR_IDLE_FRAMES

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	apply_horizontal_steering(delta)
	var was_descending := velocity.y > 0.0
	var contact_center := global_position
	move_and_slide()
	if not is_on_floor():
		_contact_latched = false
	if was_descending and is_on_floor() and not _contact_latched:
		for index in get_slide_collision_count():
			var contact := get_slide_collision(index)
			# move_and_slide can continue horizontally after impact. Reconstruct
			# the core center at each collision, not its end-of-tick position.
			contact_center += contact.get_travel()
			var platform := contact.get_collider() as JumpPlatform
			if platform != null and contact.get_normal().dot(up_direction) >= cos(floor_max_angle):
				_contact_latched = true
				_resolve_landing(platform, false, contact_center.x)
				break

## ---------------------------------------------------------------------------
## DIVE: aktive Beeinflussung des Landungszeitpunkts
## ---------------------------------------------------------------------------
##
## Einmal pro Sprung, nur in der FALLPHASE, ausgeloest durch einen schnellen
## Wisch nach unten (siehe `dive_input.gd`). Der Reaktor beschleunigt deutlich
## nach unten; waagerecht bleibt er steuerbar. Die Werte stehen in `JumpConfig`
## bei den uebrigen Spielwerten.
##
## Warum KEIN sinnvoller Tempo-Deckel fuer Dive: die Steuerung nach unten ist der
## Zweck, und ein gedeckeltes Tempo waere kein Dive. Die waagerechte Lenkung ist
## ohnehin eigenstaendig begrenzt (`MAX_HORIZONTAL_SPEED`), und der Aufprall nutzt
## dieselbe Landung wie jeder andere Sturz — es gibt keinen neuen Absturzpfad.

## Gravitation der laufenden Stufe. Die Tempoleiter skaliert Gravitation und
## Absprungkraft GEMEINSAM, damit hoeheres Tempo nicht auch hoehere Spruenge
## bedeutet. Vor dem ersten Absprung gilt die ruhige Stufe.
func current_gravity() -> float:
	var gravity := JumpConfig.pace_gravity(_held_charges(), _pending_overload, _perfect_boost_flight)
	if _dive_active:
		gravity *= JumpConfig.DIVE_GRAVITY_FACTOR
	return gravity

## Dive laeuft gerade? Nur fuer Pruefungen und QA.
func is_diving() -> bool:
	return _dive_active

## Ist ein Dive in DIESEM Sprung noch moeglich? Nur fuer Pruefungen und QA.
func dive_available() -> bool:
	return _dive_available and velocity.y > JumpConfig.DIVE_MIN_FALL_SPEED

## Loest den Dive aus. Liefert false, wenn er nicht erlaubt ist — die
## Entscheidung liegt hier und nicht in der Eingabe, damit es genau eine
## Regelstelle gibt.
func try_dive() -> bool:
	if not _dive_available:
		return false
	if velocity.y <= JumpConfig.DIVE_MIN_FALL_SPEED:
		# Noch im Aufstieg (oder im Scheitel): kein Dive. Der Spieler soll den
		# Landungszeitpunkt beeinflussen, nicht den Absprung.
		return false
	_dive_available = false
	_dive_active = true
	dive_count += 1
	# Der Kick ist der spuerbare Teil: die Gravitation allein braucht einen
	# Moment, bis sie wirkt.
	velocity.y = maxf(velocity.y, JumpConfig.DIVE_MIN_FALL_SPEED * 4.0)
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()
	return true

## Der PERFECT-Boost gilt fuer GENAU DEN NAECHSTEN Absprung.
##
## Es gibt ZWEI Flags, und das ist kein Zufall:
##   `_perfect_boost_armed`  — scharf gestellt von der Landung, verbraucht beim
##                             naechsten Absprung.
##   `_perfect_boost_flight` — scharf WAEHREND dieses einen Fluges.
##
## Warum zwei: Kraft und Gravitation lesen den Boost zu VERSCHIEDENEN Zeitpunkten.
## Die Kraft liest ihn im Absprung, die Gravitation in JEDEM Tick danach. Ein
## einziges Flag, das beim Absprung geloescht wird, laesst die Gravitation
## ungeboostet weiterlaufen — der Sprung wird dann HOEHER statt schneller
## (gemessen: Scheitel +23 %, Flugdauer +11 %, also das Gegenteil des Ziels).
var _perfect_boost_armed := false
var _perfect_boost_flight := false

## Scharfer PERFECT-Boost? Nur fuer Pruefungen und QA.
func perfect_boost_armed() -> bool:
	return _perfect_boost_armed

## Wird von der Landung gesetzt. Bewusst KEIN Stapeln und kein Timer: der Wert
## faellt genau beim naechsten Absprung, unabhaengig davon, wie lange der Flug
## dauert.
func arm_perfect_boost() -> void:
	_perfect_boost_armed = true

func apply_gravity(delta: float) -> void:
	velocity.y += current_gravity() * delta
	if _dive_active and velocity.y > JumpConfig.DIVE_MAX_FALL_SPEED:
		# Nur der Dive wird gedeckelt: ohne Deckel koennte ein sehr spaeter Dive
		# den Kern in einem einzigen Tick durch eine Plattform tragen.
		velocity.y = JumpConfig.DIVE_MAX_FALL_SPEED

func set_horizontal_intent(intent: float) -> void:
	has_horizontal_target = false
	horizontal_intent = clampf(intent, -1.0, 1.0)

func set_horizontal_target(target_x: float) -> void:
	horizontal_target_x = target_x
	has_horizontal_target = true

func clear_horizontal_target() -> void:
	has_horizontal_target = false
	horizontal_intent = 0.0

## Anteil der geladenen Resonanz (0.0 .. 1.0). Wird vom Spiel gesetzt und
## faerbt nur das Kontakt-Feedback, nicht die Physik.
func set_resonance_ratio(ratio: float) -> void:
	_resonance_ratio = clampf(ratio, 0.0, 1.0)
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()

func apply_horizontal_steering(delta: float) -> void:
	var target_speed := horizontal_intent * JumpConfig.MAX_HORIZONTAL_SPEED
	if has_horizontal_target:
		var distance := horizontal_target_x - global_position.x
		if absf(distance) <= JumpConfig.HORIZONTAL_TARGET_DEADZONE:
			target_speed = 0.0
		else:
			var proportional_speed := absf(distance) / JumpConfig.HORIZONTAL_TARGET_DISTANCE * JumpConfig.MAX_HORIZONTAL_SPEED
			var stopping_speed := sqrt(2.0 * JumpConfig.HORIZONTAL_BRAKING * absf(distance))
			target_speed = signf(distance) * minf(JumpConfig.MAX_HORIZONTAL_SPEED, minf(proportional_speed, stopping_speed))
	var rate := JumpConfig.HORIZONTAL_ACCELERATION
	if is_zero_approx(target_speed):
		rate = JumpConfig.HORIZONTAL_DRAG
	elif velocity.x * target_speed < 0.0:
		rate = JumpConfig.HORIZONTAL_REVERSAL
	elif absf(target_speed) < absf(velocity.x):
		rate = JumpConfig.HORIZONTAL_BRAKING
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	velocity.x = clampf(velocity.x, -JumpConfig.MAX_HORIZONTAL_SPEED, JumpConfig.MAX_HORIZONTAL_SPEED)

func bounce_from(platform: JumpPlatform, is_overload: bool) -> bool:
	if velocity.y <= 0.0:
		return false
	_resolve_landing(platform, is_overload, global_position.x)
	return true

## Der Absprung traegt die verbrauchte Resonanzladung. Wird in `_apply_bounce`
## gesetzt, BEVOR der Callback die Ladungen leert.
var _pending_overload := false

func _resolve_landing(platform: JumpPlatform, is_overload: bool, contact_center_x: float) -> void:
	last_landing_quality = JumpConfig.LandingQuality.NORMAL
	var bonus := 0
	if platform != null:
		last_landing_quality = platform.classify_contact((contact_center_x - platform.global_position.x) / absf(platform.global_scale.x))
		platform.trigger_impact(last_landing_quality, contact_center_x)
		bonus = platform.claim_landing_bonus(last_landing_quality)
	landing_count += 1
	# Die Landung beendet den Dive; der naechste Absprung gibt ihn neu frei.
	_dive_active = false
	_impact_remaining = JumpConfig.LANDING_EFFECT_DURATIONS[last_landing_quality]
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()
	# Der PERFECT-Boost wird HIER scharf gemacht, also von der Landung, die ihn
	# verdient hat. Er gilt fuer den Absprung, der gleich folgt — und nur fuer
	# ihn: `_apply_bounce` loescht ihn im selben Tick nach dem Auslesen.
	if last_landing_quality == JumpConfig.LandingQuality.PERFECT:
		_perfect_boost_armed = true
	# Erst die Landung verbuchen (laedt die Resonanz), dann mit dem Ergebnis
	# abspringen. So wirkt ein Overload im selben Physik-Tick wie die Landung,
	# die ihn ausgeloest hat.
	var overload := false
	if overload_check.is_valid():
		overload = bool(overload_check.call(last_landing_quality))
	else:
		overload = is_overload
	_apply_bounce(overload)
	landed.emit(platform, last_landing_quality, bonus)

## The first launch has no preceding landing. Normal landing bounces retain
## their existing land -> jump sequence and physics.
func start_initial_bounce() -> void:
	# Der Startabsprung laeuft immer auf der ruhigen Stufe: der Spieler hat noch
	# nichts geleistet, ein schnellerer erster Sprung waere nicht verdient.
	_dive_active = false
	_dive_available = true
	_perfect_boost_flight = false
	velocity.y = -JumpConfig.pace_bounce(0, false)
	_bounce_sequence = [&"jump"]
	_play_next_bounce_animation()
	bounced.emit()

func _apply_bounce(is_overload: bool) -> void:
	# Ein Dive ist genau EINMAL je Sprung moeglich: jeder Absprung gibt ihn
	# zurueck, und er ist erst wieder verfuegbar, wenn der Kern faellt
	# (`try_dive` prueft die Fallrichtung).
	_dive_active = false
	_dive_available = true
	_pending_overload = is_overload
	_overload_remaining = JumpConfig.RESONANCE_OVERLOAD_DISPLAY_TIME if is_overload else 0.0
	# Die Tempoleiter steckt in `pace_bounce` (Faktor UND Ladungsaufschlag), dazu
	# der PERFECT-Boost dieses Absprungs. Danach greift die Kappung.
	var charges := int(round(_resonance_ratio * JumpConfig.RESONANCE_MAX_CHARGES))
	var boost := _perfect_boost_armed
	# Verbrauchen, BEVOR die Kraft berechnet wird: der Booster gilt fuer genau
	# diesen einen Absprung. Ein Overload verbraucht ihn mit — die Kraft kommt
	# dann ohnehin aus OVERLOAD_BOUNCE_SPEED, und ein aufgesparter Boost nach
	# einem Overload waere ein Dauerzustand, den es nicht geben soll.
	_perfect_boost_armed = false
	# Den Boost fuer den FLUG sichtbar machen — die Gravitation liest ihn hier.
	_perfect_boost_flight = boost
	var bounce_speed := JumpConfig.pace_bounce(charges, is_overload, boost)
	velocity.y = -minf(bounce_speed * JumpConfig.LANDING_BOUNCE_MULTIPLIERS[last_landing_quality], JumpConfig.MAX_BOUNCE_SPEED)
	_bounce_sequence = [&"land", &"jump"]
	_play_next_bounce_animation()
	bounced.emit()

# One reused, local CanvasItem over the existing core. No whole-body flash,
# transforms, particles, shaders or per-contact allocations.
func shutdown() -> void:
	_overload_remaining = 0.0
	_resonance_ratio = 0.0
	_dive_active = false
	_dive_available = false
	_perfect_boost_armed = false
	_perfect_boost_flight = false
	set_physics_process(false)
	set_process(false)
	clear_horizontal_target()
	_impact_remaining = 0.0
	if _feedback_visual != null:
		_feedback_visual.queue_redraw()
	if _reactor_visual != null:
		_reactor_visual.pause()

func _draw_contact_light() -> void:
	var charge_light := JumpConfig.RESONANCE_OVERLOAD_COLOR if _overload_remaining > 0.0 else JumpConfig.LANDING_CORE_LIGHT_COLOR
	charge_light.a = charge_light_alpha()
	if charge_light.a > 0.0:
		_feedback_visual.draw_circle(JumpConfig.REACTOR_CORE_POSITION, charge_light_radius(), charge_light)
	if _overload_remaining > 0.0:
		# Auch waehrend des Flugs bleibt der Overload benannt. Die Wirkung liegt
		# bewusst AUSSERHALB der Kernsilhouette: eine weiche flache Aura und ein
		# klarer warmgoldener Ring, dieselbe Formsprache wie der Kontaktring.
		# Kein Vollkoerperflash, kein Zufallszittern, keine zusaetzlichen Knoten.
		var fade := _overload_remaining / JumpConfig.RESONANCE_OVERLOAD_DISPLAY_TIME
		var aura := JumpConfig.RESONANCE_OVERLOAD_COLOR
		aura.a = JumpConfig.OVERLOAD_AURA_ALPHA * fade
		var flight_ring := JumpConfig.RESONANCE_OVERLOAD_COLOR
		flight_ring.a = minf(1.0, JumpConfig.OVERLOAD_LIGHT_ALPHA * 2.2 * fade)
		_feedback_visual.draw_set_transform(Vector2(0.0, JumpConfig.JUMPER_SIZE.y * 0.5), 0.0, Vector2(1.0, JumpConfig.OVERLOAD_RING_FLATTEN))
		_feedback_visual.draw_circle(Vector2.ZERO, JumpConfig.OVERLOAD_AURA_RADIUS, aura)
		_feedback_visual.draw_arc(Vector2.ZERO, JumpConfig.OVERLOAD_RING_RADIUS, 0.0, TAU, JumpConfig.LANDING_RING_SEGMENTS, flight_ring, JumpConfig.OVERLOAD_RING_WIDTH)
		_feedback_visual.draw_set_transform(Vector2.ZERO)
	if _impact_remaining <= 0.0:
		return
	var duration: float = JumpConfig.LANDING_EFFECT_DURATIONS[last_landing_quality]
	var fade := _impact_remaining / duration
	var strength: float = JumpConfig.LANDING_EFFECT_STRENGTHS[last_landing_quality] * fade
	var light := JumpConfig.LANDING_CORE_LIGHT_COLOR
	light.a = strength * JumpConfig.LANDING_CORE_LIGHT_GAIN
	_feedback_visual.draw_circle(JumpConfig.REACTOR_CORE_POSITION, JumpConfig.LANDING_CORE_LIGHT_RADIUS, light)
	if last_landing_quality != JumpConfig.LandingQuality.NORMAL:
		var ring := JumpConfig.RESONANCE_HUD_CHARGE_COLOR if last_landing_quality == JumpConfig.LandingQuality.RESONANCE else JumpConfig.LANDING_GLOW_COLOR
		# Der Ladungsstand ist am Ring ablesbar, ohne zusaetzliche Objekte:
		# mehr Resonanz = hellerer und weiter gespannter Kontaktring.
		var charge_boost := _resonance_ratio * JumpConfig.RESONANCE_RING_CHARGE_GAIN
		ring.a = minf(1.0, strength * (1.0 + charge_boost))
		var radius: float = JumpConfig.LANDING_RING_RADII[last_landing_quality] + (1.0 - fade) * JumpConfig.LANDING_RING_EXPANSION
		if _pending_overload:
			# Ein entladener Overload ist im selben Moment sichtbar, in dem er
			# verbraucht wird.
			ring = JumpConfig.RESONANCE_OVERLOAD_COLOR
			ring.a = minf(1.0, strength * 2.0)
			radius += JumpConfig.LANDING_RING_EXPANSION
		_feedback_visual.draw_set_transform(Vector2(0.0, JumpConfig.JUMPER_SIZE.y * 0.5), 0.0, Vector2(1.0, JumpConfig.LANDING_RING_FLATTEN))
		_feedback_visual.draw_arc(Vector2.ZERO, radius, 0.0, TAU, JumpConfig.LANDING_RING_SEGMENTS, ring, JumpConfig.LANDING_RING_WIDTH)
		_feedback_visual.draw_set_transform(Vector2.ZERO)
