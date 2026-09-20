class_name OverloadInput
extends RefCounted

## Up-Flick mit exakt den bewaehrten Dive-Schwellen und Zeitfenstern.
## Nur die Y-Achse wird gespiegelt; DiveInput selbst bleibt unveraendert.
## Ein zusammenhaengender Aufwaertszug darf nur einmal feuern, auch wenn
## waehrenddessen ein Overload verbraucht und neu geladen wird.
const Flick = preload("res://scripts/jump/dive_input.gd")
var _flick := Flick.new()
var _fired := false

func begin(position: Vector2, now: float) -> void:
	_fired = false
	_flick.begin(Vector2(position.x, -position.y), now)

func update(position: Vector2, now: float) -> bool:
	if _fired:
		return false
	if not _flick.update(Vector2(position.x, -position.y), now,
			JumpConfig.DIVE_SWIPE_MIN_DISTANCE,
			JumpConfig.DIVE_SWIPE_MAX_TIME,
			JumpConfig.DIVE_SWIPE_DOMINANCE):
		return false
	_fired = true
	return true

func end() -> void:
	_flick.end()
	_fired = false

func reset() -> void:
	end()
