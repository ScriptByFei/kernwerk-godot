extends Node2D
## Game-Szene: Wurzel und Verkabelung der getrennten Gameplay-Systeme.

const ScoreFeedbackScript = preload("res://scripts/ui/score_feedback.gd")
const ScreenShakeScript = preload("res://scripts/game/screen_shake.gd")
const ParticleBurstScript = preload("res://scripts/effects/particle_burst.gd")
const SfxScript = preload("res://scripts/audio/sfx.gd")

const UPGRADE_PARTICLE_COLOR := Color(0.4, 1.0, 0.55)
const BOSS_PHASE_TWO_PARTICLE_COLOR := Color(0.68, 0.34, 0.82)

@export var run_seed := -1  # -1 = echter Zufall; >=0 = reproduzierbarer QA-Lauf

var game_manager: GameManager
var player_stats: PlayerStats
var player_health: PlayerHealth
var screen_shake: Node
var game_over_ui: GameOverUI
var spawner: SpawnManager
var wave_manager: WaveManager
var feedback: UpgradeFeedback
var score_feedback
var hud: Hud
var level_complete_ui: LevelCompleteUI
var pause_ui: PauseUI
var sfx
var _paused_by_focus := false

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
	sfx = SfxScript.new()
	sfx.name = "Sfx"
	add_child(sfx)
	player.weapon.bullet_fired.connect(_on_bullet_fired)

	# GameManager
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	game_manager.game_over.connect(_on_player_died)
	game_manager.state_changed.connect(_on_state_changed)

	# Spieler-Stats (Phase 5) — WeaponController liest daraus
	player_stats = PlayerStats.new()
	player_stats.name = "PlayerStats"
	add_child(player_stats)
	player.weapon.stats = player_stats

	# Die Szene hat keine Camera2D; deshalb bewegt der Shake kurz die Spielwurzel.
	screen_shake = ScreenShakeScript.new()
	screen_shake.name = "ScreenShake"
	add_child(screen_shake)
	screen_shake.setup(self)

	# Spieler-HP-System
	player_health = PlayerHealth.new()
	player_health.name = "PlayerHealth"
	add_child(player_health)
	player_health.setup(game_manager, screen_shake, sfx)

	# Game Over UI (unsichtbar bis Tod)
	game_over_ui = GameOverUI.new()
	game_over_ui.name = "GameOverUI"
	add_child(game_over_ui)
	game_over_ui.restart_pressed.connect(_restart)

	# Level Complete UI (nach letzter Welle / Boss-Kill)
	level_complete_ui = LevelCompleteUI.new()
	level_complete_ui.name = "LevelCompleteUI"
	add_child(level_complete_ui)
	level_complete_ui.continue_pressed.connect(_restart)  # MVP: Continue = neue Runde
	level_complete_ui.retry_pressed.connect(_restart)
	# Pause liegt unter Ergebnis-Modals, aber über HUD und Spielwelt.
	pause_ui = PauseUI.new()
	pause_ui.name = "PauseUI"
	add_child(pause_ui)

	# Upgrade-Feedback (aufsteigender Text über dem Spieler)
	feedback = UpgradeFeedback.new()
	feedback.name = "UpgradeFeedback"
	add_child(feedback)
	score_feedback = ScoreFeedbackScript.new()
	score_feedback.name = "ScoreFeedback"
	add_child(score_feedback)
	# HUD (Score/Kills oben, Werte unten)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.setup(player_stats, game_manager)

	# SpawnManager
	spawner = SpawnManager.new()
	spawner.name = "SpawnManager"
	add_child(spawner)
	spawner.setup(self, run_seed)
	spawner.enemy_reached_player.connect(_on_enemy_reached_player)
	spawner.boss_spawned.connect(_on_boss_spawned)

	# Phase 6: Wellen steuern Spawnparameter + Levelende
	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	add_child(wave_manager)
	wave_manager.attach(self, spawner)
	wave_manager.level_completed.connect(_on_level_completed)
	spawner.upgrade_collected_from_world.connect(_on_upgrade_collected)  # Phase-5-Kette (WaveManager-Refactor)
	spawner.enemy_killed_from_world.connect(_on_enemy_killed)
	spawner.enemy_damaged_from_world.connect(_on_enemy_damaged)
	wave_manager.wave_started.connect(_on_wave_started)
	hud.attach_wave_manager(wave_manager)
	game_manager.start_run()  # Startscreen folgt später; bis dahin sofortiger Start.
	wave_manager.start_level()

func _physics_process(_delta: float) -> void:
	if not game_manager.is_running():
		return
	HitDetection.process_hits(_collect_bullets(), get_tree().get_nodes_in_group("enemies"), get_tree().get_nodes_in_group("upgrades"))

func _on_enemy_reached_player(enemy: Enemy) -> void:
	if not game_manager.is_running():
		return
	player_health.take_hit(GameConfig.ENEMY_DAMAGE)

func _on_boss_spawned(boss: Boss) -> void:
	boss.lane_pulse_fired.connect(_on_boss_lane_pulse)
	boss.phase_two_entered.connect(_on_boss_phase_two_entered.bind(boss))

func _on_boss_phase_two_entered(boss: Boss) -> void:
	ParticleBurstScript.burst(self, boss.global_position, BOSS_PHASE_TWO_PARTICLE_COLOR, 15, 0.8)

func _on_boss_lane_pulse(lane: int) -> void:
	if not game_manager.is_running():
		return
	screen_shake.shake(5.0, 0.12)
	sfx.play("boss_pulse")
	var player := $Player as Player
	if player.current_lane == lane:
		player_health.take_hit(BossData.PULSE_DAMAGE)

func _on_level_completed() -> void:
	if not game_manager.is_running():
		return
	game_manager.complete_level()
	sfx.play("level_complete")
	level_complete_ui.show_stats(game_manager.score, game_manager.kills)

func _on_player_died() -> void:
	game_over_ui.show_stats(game_manager.score, game_manager.kills)

func _on_enemy_killed(enemy: Enemy) -> void:
	game_manager.add_kill(enemy.score_reward)
	sfx.play("kill")
	score_feedback.popup_for(enemy)
	var color := EnemyArchetypeData.get_definition(enemy.enemy_type)["color"] as Color
	ParticleBurstScript.burst(self, enemy.global_position, color, 20 if enemy.is_boss else 10, 0.6 if enemy.is_boss else 0.35)

func _on_upgrade_collected(u: UpgradeObject) -> void:
	player_stats.apply_upgrade(u.upgrade_type)
	sfx.play("upgrade")
	feedback.popup_for(u, $Player as Player)
	ParticleBurstScript.burst(self, u.global_position, UPGRADE_PARTICLE_COLOR, 8, 0.3)

func _restart() -> void:
	get_tree().reload_current_scene()

func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.RUNNING:
			_set_gameplay_processing(true)
		GameManager.State.PAUSED:
			# Nur Verarbeitung anhalten: der vorherige Spawner-Zustand bleibt
			# erhalten (wichtig in der Boss-Wartephase).
			_set_gameplay_processing(false)
		_:
			if spawner:
				spawner.set_spawning_enabled(false)
			_set_gameplay_processing(false)
	if pause_ui:
		pause_ui.show_paused(new_state == GameManager.State.PAUSED)

func _set_gameplay_processing(active: bool) -> void:
	if spawner == null or wave_manager == null:
		return
	spawner.set_physics_process(active)
	wave_manager.set_physics_process(active)
	var player := $Player as Player
	player.weapon.set_physics_process(active)
	player.touch.set_process_input(active)
	player.set_process_unhandled_input(active)
	for obj in get_tree().get_nodes_in_group("lane_objects"):
		if obj is LaneObject:
			obj.set_physics_process(active)
	for bullet in _collect_bullets():
		bullet.set_physics_process(active)

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
	match what:
		NOTIFICATION_WM_SIZE_CHANGED:
			if is_inside_tree():
				_layout_bg()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if game_manager and game_manager.is_running():
				_paused_by_focus = game_manager.pause_run()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if _paused_by_focus and game_manager and game_manager.is_paused():
				_paused_by_focus = false
				game_manager.resume_run()

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		sfx.unlock()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if game_manager.is_running():
			_paused_by_focus = false
			game_manager.pause_run()
		elif game_manager.is_paused() and not _paused_by_focus:
			game_manager.resume_run()
		get_viewport().set_input_as_handled()

func _on_lane_changed(lane: int) -> void:
	print("[Game] lane=%d" % lane)

func _on_bullet_fired(_bullet: Bullet) -> void:
	sfx.play("shoot")

func _on_enemy_damaged(_enemy: Enemy, _new_hp: int) -> void:
	sfx.play("enemy_hit")

func _on_wave_started(_wave_index: int) -> void:
	sfx.play("wave_start")
