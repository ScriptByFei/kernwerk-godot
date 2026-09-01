class_name Boss
extends Enemy
## Zwei-Phasen-Boss: hält die obere Arena, pulst seine Lane und ruft Adds.

signal lane_pulse_fired(lane: int)
signal summon_requested(summon_lanes: Array, enemy_type: String)

var is_phase_two := false
var _pulse_timer := 0.0
var _summon_timer := 0.0
var _lane_switch_timer := 0.0
var _pulse_telegraph_remaining := 0.0
var _lane_tween: Tween
var _flash_tween: Tween
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	_rng.randomize()

func configure(p_lane: int, _hp: int = BossData.BOSS_HP, _speed: float = BossData.BOSS_SPEED, _is_boss: bool = true, _enemy_type: String = EnemyArchetypeData.BOSS) -> void:
	super.configure(p_lane, BossData.BOSS_HP, BossData.BOSS_SPEED, true, EnemyArchetypeData.BOSS)

func _physics_process(delta: float) -> void:
	if not _has_reached_hover_point():
		_move_to_hover_point(delta)
		return
	_update_combat_timers(delta)

func _has_reached_hover_point() -> bool:
	return position.y >= _hover_y()

func _move_to_hover_point(delta: float) -> void:
	position.y = minf(position.y + move_speed * delta, _hover_y())

func _hover_y() -> float:
	return get_viewport_rect().size.y * BossData.HOVER_Y_RATIO

func _update_combat_timers(delta: float) -> void:
	_update_pulse(delta)
	_update_summons(delta)
	_update_lane_switch(delta)

func _update_pulse(delta: float) -> void:
	if _pulse_telegraph_remaining > 0.0:
		_pulse_telegraph_remaining -= delta
		if _pulse_telegraph_remaining <= 0.0:
			fire_lane_pulse()
		return
	_pulse_timer += delta
	if _pulse_timer >= _pulse_interval():
		_pulse_timer = 0.0
		begin_lane_pulse()

func begin_lane_pulse() -> void:
	if _pulse_telegraph_remaining > 0.0:
		return
	_pulse_telegraph_remaining = BossData.PULSE_TELEGRAPH
	_pulse_flash()
	queue_redraw()

func fire_lane_pulse() -> void:
	_pulse_telegraph_remaining = 0.0
	queue_redraw()
	lane_pulse_fired.emit(lane)
	_spawn_pulse_wave()

func _spawn_pulse_wave() -> void:
	var world := get_parent() as Node2D
	if world == null:
		return
	var wave := Polygon2D.new()
	wave.name = "LanePulseWave"
	var width := get_viewport_rect().size.x * 0.11
	wave.polygon = PackedVector2Array([Vector2(-width, -14), Vector2(width, -14), Vector2(width, 14), Vector2(-width, 14)])
	wave.color = Color(0.92, 0.45, 1.0, 0.85)
	world.add_child(wave)
	wave.global_position = Vector2(GameConfig.lane_x(lane, get_viewport_rect().size.x), global_position.y)
	var tween := wave.create_tween()
	tween.tween_property(wave, "global_position:y", get_viewport_rect().size.y + 80.0, 0.32)
	tween.tween_callback(wave.queue_free)

func _update_summons(delta: float) -> void:
	_summon_timer += delta
	if _summon_timer >= _summon_interval():
		_summon_timer = 0.0
		request_summons()

func request_summons() -> void:
	var summon_lanes := _summon_lanes(_summon_count())
	var types := BossData.SUMMON_TYPES_P2 if is_phase_two else BossData.SUMMON_TYPES_P1
	for type_index in types.size():
		var lanes_for_type: Array = []
		for lane_index in summon_lanes.size():
			if lane_index % types.size() == type_index:
				lanes_for_type.append(summon_lanes[lane_index])
		if not lanes_for_type.is_empty():
			summon_requested.emit(lanes_for_type, str(types[type_index]))

func _summon_lanes(count: int) -> Array:
	var available: Array = []
	for candidate in GameConfig.LANE_COUNT:
		if candidate != lane:
			available.append(candidate)
	_shuffle_lanes(available)
	var out: Array = []
	for index in count:
		out.append(available[index % available.size()])
	return out

func _shuffle_lanes(lanes: Array) -> void:
	for index in range(lanes.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var value = lanes[index]
		lanes[index] = lanes[swap_index]
		lanes[swap_index] = value

func _update_lane_switch(delta: float) -> void:
	_lane_switch_timer += delta
	if _lane_switch_timer >= _lane_switch_interval():
		_lane_switch_timer = 0.0
		weave_to_next_lane()

func weave_to_next_lane() -> void:
	var offset := _rng.randi_range(1, GameConfig.LANE_COUNT - 1)
	lane = (lane + offset) % GameConfig.LANE_COUNT
	if _lane_tween and _lane_tween.is_valid():
		_lane_tween.kill()
	_lane_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lane_tween.tween_property(self, "position:x", lane_x_now(), BossData.LANE_SWITCH_DURATION)

func _pulse_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	for _blink in 3:
		_flash_tween.tween_property(self, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.08)
		_flash_tween.tween_property(self, "modulate", _base_modulate(), 0.08)

func _base_modulate() -> Color:
	return Color(1.18, 0.78, 1.24, 1.0) if is_phase_two else Color.WHITE

func _pulse_interval() -> float:
	return BossData.PULSE_INTERVAL_P2 if is_phase_two else BossData.PULSE_INTERVAL_P1

func _summon_interval() -> float:
	return BossData.SUMMON_INTERVAL_P2 if is_phase_two else BossData.SUMMON_INTERVAL_P1

func _summon_count() -> int:
	return BossData.SUMMON_COUNT_P2 if is_phase_two else BossData.SUMMON_COUNT_P1

func _lane_switch_interval() -> float:
	return BossData.LANE_SWITCH_INTERVAL_P2 if is_phase_two else BossData.LANE_SWITCH_INTERVAL_P1

func take_damage(dmg: int) -> void:
	var was_phase_two := is_phase_two
	super.take_damage(dmg)
	if not was_phase_two and current_hp > 0 and float(current_hp) / float(max_hp) <= BossData.PHASE2_THRESHOLD:
		_enter_phase_two()

func _enter_phase_two() -> void:
	is_phase_two = true
	scale = Vector2(1.12, 1.12)
	modulate = _base_modulate()
	_pulse_flash()

func _draw() -> void:
	if _pulse_telegraph_remaining <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	var stripe_width := viewport_size.x * 0.12
	var stripe_height := maxf(viewport_size.y - global_position.y, 0.0)
	draw_rect(Rect2(Vector2(-stripe_width * 0.5, 0.0), Vector2(stripe_width, stripe_height)), Color(0.88, 0.35, 1.0, 0.24))
