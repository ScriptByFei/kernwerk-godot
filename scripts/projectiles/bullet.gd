class_name Bullet
extends Node2D
## Einfaches Projektil: fliegt nach oben, despawnt außerhalb des Bildschirms.
## Erweiterbar: Schaden, Durchschuss, explosive Typen — später über Properties/Export.

var damage := GameConfig.DAMAGE
var speed := GameConfig.BULLET_SPEED
var _mark_for_free := false

func _ready() -> void:
	# Kleines Rechteck als MVP-Platzhalter
	var rect := Polygon2D.new()
	rect.polygon = PackedVector2Array([Vector2(-8, -18), Vector2(8, -18), Vector2(8, 18), Vector2(-8, 18)])
	rect.color = Color(1.0, 0.92, 0.35)
	add_child(rect)

func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	# Bildschirmrand (Referenz 1920 hoch) — despawan
	if position.y < -60.0:
		queue_free()

func setup(dmg: int, spd: float) -> void:
	damage = dmg
	speed = spd