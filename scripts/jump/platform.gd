class_name JumpPlatform
extends StaticBody2D

var platform_size := JumpConfig.PLATFORM_SIZE
var impact_count := 0
var impact_quality := JumpConfig.LandingQuality.NORMAL
var impact_elapsed := 0.0
var impact_active := false
var _impact_local_x := 0.0
var _bonus_claimed := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = platform_size
	collision.shape = shape
	collision.one_way_collision = true
	add_child(collision)
	set_process(false)
	queue_redraw()

func trigger_impact(quality: JumpConfig.LandingQuality, core_world_x: float) -> void:
	impact_quality = quality
	impact_elapsed = 0.0
	impact_active = true
	impact_count += 1
	_impact_local_x = to_local(Vector2(core_world_x, global_position.y)).x
	set_process(true)
	queue_redraw()

# Feedback repeats on legitimate subsequent landings; rewards cannot be farmed.
func claim_landing_bonus(quality: JumpConfig.LandingQuality, enabled := JumpConfig.LANDING_BONUSES_ENABLED) -> int:
	if _bonus_claimed:
		return 0
	_bonus_claimed = true
	return JumpConfig.LANDING_SCORE_BONUSES[quality] if enabled else 0

func _process(delta: float) -> void:
	impact_elapsed += delta
	if impact_elapsed >= JumpConfig.LANDING_EFFECT_DURATIONS[impact_quality]:
		impact_active = false
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-platform_size * 0.5, platform_size)
	draw_rect(rect, JumpConfig.PLATFORM_BODY_COLOR)
	draw_rect(Rect2(rect.position.x, rect.end.y - JumpConfig.PLATFORM_SHADOW_HEIGHT, rect.size.x, JumpConfig.PLATFORM_SHADOW_HEIGHT), JumpConfig.PLATFORM_SHADOW_COLOR)
	for x in [rect.position.x, rect.end.x - JumpConfig.PLATFORM_ENDCAP_WIDTH]:
		draw_rect(Rect2(x, rect.position.y, JumpConfig.PLATFORM_ENDCAP_WIDTH, rect.size.y), JumpConfig.PLATFORM_ENDCAP_COLOR)
	draw_rect(rect, JumpConfig.PLATFORM_OUTLINE_COLOR, false, JumpConfig.PLATFORM_OUTLINE_WIDTH)
	# Edge starts at the exact collider top, never moves with the socket impulse.
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, JumpConfig.PLATFORM_EDGE_HEIGHT)), JumpConfig.PLATFORM_EDGE_COLOR)
	var strength := 0.0
	if impact_active:
		strength = 1.0 - clampf(impact_elapsed / JumpConfig.LANDING_EFFECT_DURATIONS[impact_quality], 0.0, 1.0)
	var socket_y: float = rect.position.y + JumpConfig.PLATFORM_EDGE_HEIGHT + strength * JumpConfig.PLATFORM_IMPACT_DEPTH[impact_quality]
	var inset := JumpConfig.PLATFORM_CENTER_INSET_SIZE
	draw_rect(Rect2(Vector2(-inset.x * 0.5, socket_y), inset), JumpConfig.PLATFORM_CENTER_INSET_COLOR)
	var mark := JumpConfig.PLATFORM_CENTER_MARK_SIZE
	draw_rect(Rect2(Vector2(-mark.x * 0.5, socket_y), mark), JumpConfig.PLATFORM_CENTER_MARK_COLOR)
	var stem := JumpConfig.PLATFORM_CENTER_STEM_SIZE
	draw_rect(Rect2(Vector2(-stem.x * 0.5, socket_y), stem), JumpConfig.PLATFORM_CENTER_MARK_COLOR)
	if not impact_active:
		return
	var color: Color = JumpConfig.PLATFORM_IMPACT_COLORS[impact_quality]
	color.a = strength * JumpConfig.PLATFORM_IMPACT_ALPHAS[impact_quality]
	var width: float = JumpConfig.PLATFORM_IMPACT_WIDTHS[impact_quality]
	var center := _impact_local_x if impact_quality == JumpConfig.LandingQuality.NORMAL else 0.0
	var left := maxf(rect.position.x, center - width * 0.5)
	var right := minf(rect.end.x, center + width * 0.5)
	draw_rect(Rect2(left, rect.position.y, maxf(0.0, right - left), JumpConfig.PLATFORM_EDGE_HEIGHT), color)
	if impact_quality == JumpConfig.LandingQuality.PERFECT:
		var progress := clampf(impact_elapsed / JumpConfig.PERFECT_DASH_DURATION, 0.0, 1.0)
		var distance := lerpf(JumpConfig.PERFECT_DASH_TRAVEL.x, JumpConfig.PERFECT_DASH_TRAVEL.y, progress)
		var dash_color := JumpConfig.PERFECT_DASH_COLOR
		dash_color.a = (1.0 - progress) * JumpConfig.PERFECT_DASH_ALPHA
		for side in [-1.0, 1.0]:
			var dash_center: float = side * distance
			var dash_left := maxf(rect.position.x, dash_center - JumpConfig.PERFECT_DASH_SIZE.x * 0.5)
			var dash_right := minf(rect.end.x, dash_center + JumpConfig.PERFECT_DASH_SIZE.x * 0.5)
			draw_rect(Rect2(dash_left, socket_y, maxf(0.0, dash_right - dash_left), JumpConfig.PERFECT_DASH_SIZE.y), dash_color)
