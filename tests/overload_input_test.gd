extends SceneTree

const Up = preload("res://scripts/jump/overload_input.gd")
var checks := 0
var failures := 0

func _init() -> void:
	for hz in [30, 60, 120, 240]:
		for dx in [0.0, 20.0, -20.0]:
			_check(_gesture(Vector2(dx, -120), 0.25, hz) == 1, "up flick once at %d Hz dx=%s" % [hz, dx])
		_check(_gesture(Vector2(0, 120), 0.25, hz) == 0, "down is never up")
		_check(_gesture(Vector2(300, -80), 0.25, hz) == 0, "horizontal steering never up")
		_check(_gesture(Vector2(0, -120), 1.2, hz) == 0, "slow drag never up")
		_check(_gesture(Vector2(0, -35), 0.15, hz) == 0, "short twitch never up")
		_check(_gesture(Vector2(0, -600), 0.25, hz) == 1, "long same stroke triggers once")
	var up := Up.new()
	_check(not up.update(Vector2(0, -200), 0.1), "inactive detector ignores motion")
	up.begin(Vector2.ZERO, 0.0)
	_check(not up.update(Vector2(0, -60), 0.04), "jitter first half subthreshold")
	_check(not up.update(Vector2(0, -1), 0.08), "jitter return no activation")
	_check(not up.update(Vector2(0, -21), 0.12), "cumulative vertical jitter rejected")
	up.end()
	_check(not up.update(Vector2(0, -500), 0.15), "release clears history")
	up.begin(Vector2.ZERO, 1.0)
	_check(up.update(Vector2(0, -120), 1.1), "fresh stroke triggers")
	up.reset()
	_check(not up.update(Vector2(0, -500), 1.2), "reset clears history")
	print("OVERLOAD INPUT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _gesture(delta: Vector2, duration: float, hz: int) -> int:
	var up := Up.new()
	up.begin(Vector2.ZERO, 0.0)
	var count := 0
	var steps := ceili(duration * hz)
	for i in range(1, steps + 1):
		var part := float(i) / steps
		var p := delta * part
		p.x += 2.0 if i % 2 else -2.0
		if up.update(p, duration * part):
			count += 1
	return count

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
