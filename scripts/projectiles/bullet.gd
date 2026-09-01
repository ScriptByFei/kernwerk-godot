class_name Bullet
extends Node2D
## Einfaches Projektil: fliegt nach oben, despawnt außerhalb des Bildschirms.
## Erweiterbar: Schaden, Durchschuss, explosive Typen — später über Properties/Export.

var damage := GameConfig.DAMAGE
var speed := GameConfig.BULLET_SPEED
var _mark_for_free := false

const BULLET_COLOR := Color(1.0, 0.94, 0.62, 0.94)

func _ready() -> void:
	# Spitze nach oben: die Flugrichtung bleibt auch in Bewegung lesbar.
	var tip := Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(0, -18), Vector2(9, 4), Vector2(0, 18), Vector2(-9, 4)])
	tip.color = BULLET_COLOR
	add_child(tip)

func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	# Despawn: global prüfen — Bullet ist Kind der Welt (kein relativer Offset mehr relevant)
	if global_position.y < -60.0:
		queue_free()

func setup(dmg: int, spd: float) -> void:
	damage = dmg
	speed = spd
