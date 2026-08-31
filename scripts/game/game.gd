extends Node2D
## Game-Szene: Wurzel. Phase 2 — Bewegung + Auto-Fire.

func _ready() -> void:
	var player := $Player as Player
	player.lane_changed.connect(_on_lane_changed)

func _on_lane_changed(lane: int) -> void:
	print("[Game] lane=%d" % lane)