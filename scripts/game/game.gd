extends Node2D
## Game-Szene: Wurzel. Phase 3 — Bewegung + Auto-Fire + Gegner + Treffer.

func _ready() -> void:
	# Hintergrund dynamisch: überdeckt IMMER den ganzen Viewport (kein fixed 1080x1920)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.07, 0.08, 0.12)
	# KRITISCH: Hintergrund muss das ERSTE Child sein — sonst überdeckt er
	# Player & LaneMarkers (die in der Szene VOR ihm liegen). Genau das war der Bug.
	add_child(bg)
	move_child(bg, 0)
	_layout_bg()

	var player := $Player as Player
	player.lane_changed.connect(_on_lane_changed)

	# Phase 3: SpawnManager + HitDetection
	var spawner := SpawnManager.new()
	spawner.name = "SpawnManager"
	add_child(spawner)
	spawner.setup(self)
	# Phase 6 macht Differenzierung → jetzt linear
	spawner.set_difficulty(1.0)

func _physics_process(_delta: float) -> void:
	# Bullet→Enemy-Kollision zentral abwickeln (keine Physik-Engine)
	HitDetection.process_hits(_collect_bullets(), get_tree().get_nodes_in_group("enemies"))

func _collect_bullets() -> Array:
	var out: Array = []
	for c in get_children():
		if c is Bullet:
			out.append(c)
	return out

func _layout_bg() -> void:
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.position = Vector2.ZERO
		bg.size = get_viewport_rect().size

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and is_inside_tree():
		_layout_bg()

func _on_lane_changed(lane: int) -> void:
	print("[Game] lane=%d" % lane)