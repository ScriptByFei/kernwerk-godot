class_name HitDetection
extends Node
## Bullet→LaneObject-Kollision: Distanz-Check pro Bullet gegen Enemies UND Upgrades.
## Bewusst KEN Physik-Engine: leichter im Web-Export, deterministisch.

static func process_hits(bullets: Array, enemies: Array, upgrades: Array = []) -> void:
	for b in bullets:
		if not is_instance_valid(b):
			continue
		# Gegner
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if absf(b.global_position.x - e.global_position.x) < 60.0 \
					and absf(b.global_position.y - e.global_position.y) < 70.0:
				e.take_damage(b.damage)
				b.queue_free()
				break
		# Upgrade-Objekte (großzügigere Hitbox als Gegner: ±100x80 — einfacher einzusammeln)
		for u in upgrades:
			if not is_instance_valid(u):
				continue
			if absf(b.global_position.x - u.global_position.x) < 100.0 \
					and absf(b.global_position.y - u.global_position.y) < 100.0:
				u.collect()
				b.queue_free()
				break