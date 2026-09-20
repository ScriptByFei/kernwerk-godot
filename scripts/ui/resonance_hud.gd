class_name ResonanceHud
extends Control

## Bestehendes Bildschirm-HUD: READY/ARMED bleiben in derselben Segmentzeile.
var resonance: ResonanceSystem
var score := 0
## Restlaufzeit des tatsaechlich verbrauchten Overload-Flugs, vom Spiel gesetzt.
var overload_display := 0.0
var _pulse_time := 0.0
var _arm_impulse := 0.0
const ARMED_COLOR := Color(1.0, 0.95, 0.76)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if resonance != null:
		resonance.overload_armed.connect(_on_overload_armed)
	set_process(true)

func _on_overload_armed() -> void:
	_arm_impulse = JumpConfig.RESONANCE_ARM_IMPULSE_TIME
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_time += delta
	_arm_impulse = maxf(0.0, _arm_impulse - delta)
	if resonance != null and not resonance.is_overload_armed():
		_arm_impulse = 0.0
	queue_redraw()

func _draw() -> void:
	if resonance == null:
		return
	draw_string(
		ThemeDB.fallback_font,
		JumpConfig.RESONANCE_HUD_ORIGIN,
		"SCORE %06d" % score,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		42,
		Color(0.72, 1.0, 0.92)
	)
	_draw_charges()

func status_label() -> String:
	if resonance.is_overload_armed():
		return JumpConfig.RESONANCE_ARMED_LABEL
	if resonance.is_overload_ready():
		return JumpConfig.RESONANCE_READY_LABEL
	return JumpConfig.RESONANCE_OVERLOAD_LABEL if overload_display > 0.0 else ""

func _draw_charges() -> void:
	var charges := resonance.charges
	var max_charges := resonance.max_charges()
	var segment: Vector2 = JumpConfig.RESONANCE_HUD_SEGMENT_SIZE
	var gap: float = JumpConfig.RESONANCE_HUD_SEGMENT_GAP
	var base: Vector2 = JumpConfig.RESONANCE_HUD_ORIGIN + Vector2(0.0, JumpConfig.RESONANCE_HUD_ROW_OFFSET)
	var ready := resonance.is_overload_ready()
	var armed := resonance.is_overload_armed()
	var gold := JumpConfig.RESONANCE_OVERLOAD_COLOR
	if ready:
		gold.a *= 0.86 + 0.14 * sin(_pulse_time * TAU / JumpConfig.RESONANCE_READY_PULSE_PERIOD)
	for index in max_charges:
		var rect := Rect2(base + Vector2(index * (segment.x + gap), 0.0), segment)
		if overload_display > 0.0:
			draw_rect(rect, JumpConfig.RESONANCE_OVERLOAD_COLOR)
		elif index < charges:
			draw_rect(rect, ARMED_COLOR if armed else (gold if ready else JumpConfig.RESONANCE_HUD_CHARGE_COLOR))
		draw_rect(rect, JumpConfig.RESONANCE_HUD_DIM_COLOR, false, JumpConfig.RESONANCE_HUD_OUTLINE_WIDTH)
		if armed:
			# Helle Fuellung plus goldene Unterkante: auch ohne Text unterscheidbar.
			draw_line(rect.position + Vector2(0.0, segment.y + JumpConfig.RESONANCE_ARMED_UNDERLINE_OFFSET), rect.end + Vector2(0.0, JumpConfig.RESONANCE_ARMED_UNDERLINE_OFFSET), JumpConfig.RESONANCE_OVERLOAD_COLOR, 4.0)
			if _arm_impulse > 0.0:
				var impulse := JumpConfig.RESONANCE_OVERLOAD_COLOR
				impulse.a = _arm_impulse / JumpConfig.RESONANCE_ARM_IMPULSE_TIME
				draw_rect(rect.grow(3.0 + 10.0 * (1.0 - impulse.a)), impulse, false, 4.0)
	var label := status_label()
	if not label.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			base + Vector2(JumpConfig.resonance_hud_width() + 18.0, segment.y - 3.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			28 if ready or armed else 22,
			ARMED_COLOR if armed else JumpConfig.RESONANCE_OVERLOAD_COLOR
		)
