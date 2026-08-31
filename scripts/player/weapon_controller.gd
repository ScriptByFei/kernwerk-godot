class_name WeaponController
extends Node
## Automatisches Feuer: keine Feuertaste. Spawnt Bullets an der Waffenposition.
## Erweiterbar: mehrere Projektile, Spread, andere Waffentypen (später).

signal bullet_fired(bullet: Bullet)

var damage := GameConfig.DAMAGE
var fire_rate := GameConfig.FIRE_RATE  # Schüsse/Sekunde
var bullet_speed := GameConfig.BULLET_SPEED
var bullet_count := GameConfig.BULLET_COUNT
var spread := GameConfig.SPREAD

var _cooldown := 0.0
var _player: Player

func setup(player: Player) -> void:
	_player = player

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = 1.0 / fire_rate
		_fire()

func _fire() -> void:
	var origin := _player.global_position + Vector2(0, -80)  # Waffenposition über Kopf
	for i in bullet_count:
		var b := Bullet.new()
		b.setup(damage, bullet_speed)
		var offset_x := 0.0
		if bullet_count > 1:
			offset_x = (float(i) - (bullet_count - 1) / 2.0) * 60.0 + (randf() - 0.5) * spread
		#global statt lokal: Parent ist der Player → sonst Doppel-Offset
		get_parent().add_child(b)
		b.global_position = origin + Vector2(offset_x, 0)
		bullet_fired.emit(b)