class_name Player
extends Node2D
## Soldat: 3 feste Lanes, weiche Bewegung. Automatisches Feuer kommt in Phase 2.

signal lane_changed(lane: int)

var current_lane := 1
var _switch_tween: Tween
var _last_viewport_size := Vector2.ZERO

const SOLDIER_BLUE := Color(0.25, 0.55, 1.0)
const SOLDIER_OUTLINE_BLUE := Color(0.10, 0.27, 0.56)

@onready var touch: TouchInput = $TouchInput
@onready var weapon: WeaponController = $WeaponController

func _ready() -> void:
	_build_visual()
	_apply_layout()
	_last_viewport_size = get_viewport_rect().size
	touch.swiped.connect(move_lane)
	touch.tapped_lane.connect(move_to_lane)
	weapon.setup(self)
	set_process(true)

func _build_visual() -> void:
	# Der bestehende Soldier-Node bleibt der kompakte Torso; die Außenmaße bleiben unverändert.
	var torso := get_node_or_null("Soldier") as Polygon2D
	if torso == null:
		return
	torso.color = SOLDIER_BLUE
	torso.polygon = PackedVector2Array([Vector2(-42, -8), Vector2(42, -8), Vector2(48, 62), Vector2(-48, 62)])
	_add_visual_part(PackedVector2Array([Vector2(-60, -6), Vector2(-38, -18), Vector2(-31, 8), Vector2(-55, 17)]), SOLDIER_OUTLINE_BLUE)
	_add_visual_part(PackedVector2Array([Vector2(60, -6), Vector2(38, -18), Vector2(31, 8), Vector2(55, 17)]), SOLDIER_OUTLINE_BLUE)
	_add_visual_part(PackedVector2Array([Vector2(-28, -66), Vector2(28, -66), Vector2(38, -51), Vector2(28, -30), Vector2(-28, -30), Vector2(-38, -51)]), SOLDIER_OUTLINE_BLUE)
	_add_visual_part(PackedVector2Array([Vector2(-22, -61), Vector2(22, -61), Vector2(30, -50), Vector2(22, -36), Vector2(-22, -36), Vector2(-30, -50)]), SOLDIER_BLUE)

func _add_visual_part(points: PackedVector2Array, part_color: Color) -> void:
	var part := Polygon2D.new()
	part.polygon = points
	part.color = part_color
	add_child(part)

func _process(_delta: float) -> void:
	# Viewport kann sich im Web-Export dynamisch ändern (iOS-URL-Bar, Rotation).
	# Größe jedes Frame prüfen, aber nur bei echter Änderung neu layouten. Dadurch
	# bleibt der Lane-Tween intakt und wird nicht im nächsten Frame weggesnappt.
	var viewport_size := get_viewport_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_apply_layout()

func _unhandled_input(event: InputEvent) -> void:
	# Desktop/Entwicklung
	if event.is_action_pressed("lane_left"):
		move_lane(-1)
	elif event.is_action_pressed("lane_right"):
		move_lane(1)
	elif event.is_action_pressed("lane_1"):
		move_to_lane(0)
	elif event.is_action_pressed("lane_2"):
		move_to_lane(1)
	elif event.is_action_pressed("lane_3"):
		move_to_lane(2)

func move_lane(dir: int) -> void:
	move_to_lane(current_lane + dir)

func move_to_lane(lane: int) -> void:
	var target := clampi(lane, 0, GameConfig.LANE_COUNT - 1)
	if target == current_lane:
		return
	current_lane = target
	lane_changed.emit(current_lane)
	var target_x := _lane_x(current_lane)
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
	# Weicher Lane-Wechsel: sanfte Ease-Out-Bewegung, kein harter Snap
	_switch_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_switch_tween.tween_property(self, "position:x", target_x, GameConfig.LANE_SWITCH_TIME)

func _lane_x(lane: int) -> float:
	return GameConfig.lane_x(lane, get_viewport_rect().size.x)

func _player_y() -> float:
	return GameConfig.player_y(get_viewport_rect().size.y)

func _apply_layout() -> void:
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
	position = Vector2(_lane_x(current_lane), _player_y())

func _notification(what: int) -> void:
	# Bei Größenänderung (Rotation/Resize) Position neu anpassen
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_apply_layout()
