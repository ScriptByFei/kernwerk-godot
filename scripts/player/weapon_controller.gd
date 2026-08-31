class_name WeaponController
extends Node
## Automatisches Feuer: keine Feuertaste. Spawnt Bullets an der Waffenposition.
## Werte kommen aus PlayerStats (Phase 5) — Upgrades wirken hier direkt.
## Erweiterbar: mehrere Projektile, Spread, andere Waffentypen (später).

signal bullet_fired(bullet: Bullet)

var stats: PlayerStats
var _cooldown := 0.0
var _player: Player

func setup(player: Player) -> void:
	_player = player

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = 1.0 / _fire_rate()
		_fire()

func _fire_rate() -> float:
	return stats.fire_rate if stats else GameConfig.FIRE_RATE

func _damage() -> int:
	return stats.damage if stats else GameConfig.DAMAGE

func _soldiers() -> int:
	return stats.soldiers if stats else 1

func _fire() -> void:
	var origin := _player.global_position + Vector2(0, -80)  # Waffenposition über Kopf
	var count := _soldiers()
	# Mehrere Soldaten = mehrere Projektile pro Schuss (echte Feuerkraft)
	for i in count:
		var b := Bullet.new()
		b.setup(_damage(), GameConfig.BULLET_SPEED)
		var offset_x := 0.0
		if count > 1:
			offset_x = (float(i) - (count - 1) / 2.0) * 80.0
		# Bullet in die Welt (Game-Root) hängen, NICHT in den Player:
		# sonst würde es beim Lanewechsel mitwandern und in Spieler-Koordinaten despawnen.
		var world := _player.get_parent()
		world.add_child(b)
		b.global_position = origin + Vector2(offset_x, 0)
		bullet_fired.emit(b)