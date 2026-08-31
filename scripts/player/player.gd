class_name Player
extends Node2D
## Soldat: 3 feste Lanes, weiche Bewegung. Automatisches Feuer kommt in Phase 2.

signal lane_changed(lane: int)

var current_lane := 1
var _switch_tween: Tween

@onready var touch: TouchInput = $TouchInput
@onready var weapon: WeaponController = $WeaponController

func _ready() -> void:
	position = Vector2(GameConfig.LANE_X[current_lane], GameConfig.PLAYER_Y)
	touch.swiped.connect(move_lane)
	touch.tapped_lane.connect(move_to_lane)
	weapon.setup(self)

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
	var target_x: float = GameConfig.LANE_X[current_lane]
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
	# Weicher Lane-Wechsel: sanfte Ease-Out-Bewegung, kein harter Snap
	_switch_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_switch_tween.tween_property(self, "position:x", target_x, GameConfig.LANE_SWITCH_TIME)