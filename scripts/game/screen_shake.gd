class_name ScreenShake
extends Node
## Einmaliger Kamera- bzw. Welt-Offset für kurze Trefferimpulse.

var _target: Node2D
var _origin := Vector2.ZERO
var _tween: Tween

func setup(target: Node2D) -> void:
	_target = target
	_origin = target.position

func shake(amplitude: float, duration: float) -> void:
	if _target == null or amplitude <= 0.0 or duration <= 0.0:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_target.position = _origin
	_target.position += Vector2(1.0, 0.35).normalized() * amplitude
	_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_target, "position", _origin, duration)
