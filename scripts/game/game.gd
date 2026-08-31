extends Node2D
## Game-Szene: Wurzel. Phase 5 — Bewegung + Auto-Fire + Gegner + Treffer + HP + Game Over + Upgrades.

const ENEMY_DAMAGE := 10       # Schaden pro durchgekommenem Gegner
const ENEMY_REACH_Y_RATIO := 0.82  # Gegner-Unterkante ab hier = "erreicht Spieler"

var game_manager: GameManager
var player_stats: PlayerStats
var player_health: PlayerHealth
var game_over_ui: GameOverUI
var spawner: SpawnManager
var feedback: UpgradeFeedback
var hud: Hud

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

	# Spieler-Stats (Phase 5) — WeaponController liest daraus
	player_stats = PlayerStats.new()
	player_stats.name = "PlayerStats"
	add_child(player_stats)
	player.weapon.stats = player_stats

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

	# Upgrade-Feedback (aufsteigender Text über dem Spieler)
	feedback = UpgradeFeedback.new()
	feedback.name = "UpgradeFeedback"
	add_child(feedback)
	# HUD (Score/Kills oben, Werte unten)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(player_stats, game_manager)

	# SpawnManager
	spawner = SpawnManager.new()
	spawner.name = "SpawnManager"
	add_child(spawner)
	spawner.setup(self)
	spawner.set_difficulty(1.0)
	# SpawnManager leitet upgrade_collected weiter (Objekte spawnt er selbst)
	spawner.upgrade_collected_from_world.connect(_on_upgrade_collected)

func _physics_process(_delta: float) -> void:
	if not game_manager.is_running():
		return
	HitDetection.process_hits(_collect_bullets(), get_tree().get_nodes_in_group("enemies"), get_tree().get_nodes_in_group("upgrades"))
	_check_enemy_reach()

func _check_enemy_reach() -> void:
	var reach_y := get_viewport_rect().size.y * 0.82
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.global_position.y >= reach_y:
			player_health.take_hit(ENEMY_DAMAGE)
			e.set_physics_process(false)
			e.queue_free()

func _on_player_died() -> void:
	game_over_ui.show_stats(game_manager.score, game_manager.kills)
	spawner.set_physics_process(false)

func _on_upgrade_collected(u: UpgradeObject) -> void:
	player_stats.apply_upgrade(u.upgrade_type)
	feedback.popup_for(u, $Player as Player)

func _restart() -> void:
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