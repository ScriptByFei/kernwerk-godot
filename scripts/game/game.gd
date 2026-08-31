extends Node2D
## Game-Szene: Wurzel. Phase 4 — Bewegung + Auto-Fire + Gegner + Treffer + HP + Game Over.

# Gameplay-Konstanten Phase 4
const ENEMY_DAMAGE := 10       # Schaden pro durchgekommenem Gegner
const ENEMY_REACH_Y_RATIO := 0.82  # Gegner-Unterkante ab hier = "erreicht Spieler"

var game_manager: GameManager
var player_health: PlayerHealth
var game_over_ui: GameOverUI
var spawner: SpawnManager

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

	# GameManager
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)

	# Spieler-HP-System
	player_health = PlayerHealth.new()
	player_health.name = "PlayerHealth"
	add_child(player_health)
	player_health.player_died.connect(_on_player_died)

	# Game Over UI (unsichtbar bis Tod)
	game_over_ui = GameOverUI.new()
	game_over_ui.name = "GameOverUI"
	add_child(game_over_ui)
	game_over_ui.restart_pressed.connect(_restart)

	# Phase 3: SpawnManager
	spawner = SpawnManager.new()
	spawner.name = "SpawnManager"
	add_child(spawner)
	spawner.setup(self)
	spawner.set_difficulty(1.0)

func _physics_process(_delta: float) -> void:
	if not game_manager.is_running():
		return
	# Bullet→Enemy-Kollision zentral abwickeln (keine Physik-Engine)
	HitDetection.process_hits(_collect_bullets(), get_tree().get_nodes_in_group("enemies"))
	_check_enemy_reach()

func _check_enemy_reach() -> void:
	# Gegner, die den Spieler-Bereich erreichen, verursachen Schaden und lösen sich auf
	var reach_y := get_viewport_rect().size.y * 0.82
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.global_position.y >= reach_y:
			player_health.take_hit(ENEMY_DAMAGE)
			e.set_physics_process(false)
			e.queue_free()

func _on_player_died() -> void:
	game_over_ui.show_stats(game_manager.score, game_manager.kills)
	spawner.set_physics_process(false)

func _restart() -> void:
	# Szene neu laden (kein Web-Reload — Godot wechselt intern die Szene)
	get_tree().reload_current_scene()

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