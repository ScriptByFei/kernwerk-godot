class_name Bullet
extends Node2D
## Einfaches Projektil: fliegt nach oben, despawnt außerhalb des Bildschirms.
## Erweiterbar: Schaden, Durchschuss, explosive Typen — später über Properties/Export.

var damage := GameConfig.DAMAGE
var speed := GameConfig.BULLET_SPEED
var _mark_for_free := false

const BULLET_TEXTURE := preload("res://assets/sprites/bullet.png")
const BULLET_SPRITE_SCALE := 2.0

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = BULLET_TEXTURE
	sprite.scale = Vector2.ONE * BULLET_SPRITE_SCALE
	add_child(sprite)

func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	# Despawn: global prüfen — Bullet ist Kind der Welt (kein relativer Offset mehr relevant)
	if global_position.y < -60.0:
		queue_free()

func setup(dmg: int, spd: float) -> void:
	damage = dmg
	speed = spd
