class_name HitDetection
extends Node
## Bullet→Enemy-Kollision: Distanz-Check pro Bullet gegen Enemies.
## Bewusst KEIN Physics-Engine-Kontakt: lighter im Web-Export, voll deterministisch.

static func process_hits(bullets: Array, enemies: Array) -> void:
	for b in bullets:
		if not is_instance_valid(b):
			continue
		for e in enemies:
			if not is_instance_valid(e):
				continue
			# Gleiche Lane + vertikale Überlappung = Treffer (Lane-basiert, exakt genug fürs Spielgefühl)
			if absf(b.global_position.x - e.global_position.x) < 60.0 \
					and absf(b.global_position.y - e.global_position.y) < 70.0:
				e.take_damage(b.damage)
				b.queue_free()
				break