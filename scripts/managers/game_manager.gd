class_name GameManager
extends Node
## Zentraler Spielzustand: Score, Kills, Player-HP, Game-State.
## Keine Gameplay-Logik hier — nur Zustand + Signale. Systeme fragen/ändern über Methoden.

signal score_changed(score: int)
signal kills_changed(kills: int)
signal player_health_changed(hp: int, max_hp: int)
signal game_over
signal game_restarted

enum State { RUNNING, GAME_OVER }

var state: int = State.RUNNING
var score := 0
var kills := 0
var player_hp := GameConfig.MAX_HEALTH
var _max_health := GameConfig.MAX_HEALTH

static var instance: GameManager

func _ready() -> void:
	instance = self
	add_to_group("game_manager")

func reset() -> void:
	state = State.RUNNING
	score = 0
	kills = 0
	player_hp = _max_health
	game_restarted.emit()
	score_changed.emit(score)
	kills_changed.emit(kills)
	player_health_changed.emit(player_hp, _max_health)

func add_score(points: int) -> void:
	if state != State.RUNNING:
		return
	score += points
	score_changed.emit(score)

func add_kill() -> void:
	if state != State.RUNNING:
		return
	kills += 1
	add_score(10)

func damage_player(dmg: int) -> void:
	if state != State.RUNNING:
		return
	player_hp = maxi(player_hp - dmg, 0)
	player_health_changed.emit(player_hp, _max_health)
	if player_hp <= 0:
		state = State.GAME_OVER
		game_over.emit()

func is_running() -> bool:
	return state == State.RUNNING