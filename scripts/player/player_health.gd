class_name PlayerHealth
extends Node2D
## Spieler-HP-Visualisierung: dezente Leiste unten + rote Vignette bei Schaden (sanft).
## Schadens-/GameOver-Logik liegt im GameManager; hier nur Darstellung + Kollisions-Reaktion.

const DAMAGE_ON_REACH := 10       # Schaden pro durchgekommenem Gegner
const IFRAMES_SEC := 0.8          # Unverwundbarkeit nach Treffer (verhindert Multi-Hit)

signal player_died

var hp := GameConfig.MAX_HEALTH
var max_hp := GameConfig.MAX_HEALTH
var _iframes := 0.0
var _vignette: ColorRect
var _bar: ColorRect
var _bar_bg: ColorRect
var _game_over := false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vp := get_viewport_rect().size
	# Vignette: full-screen rot, unsichtbar, blendet bei Schaden kurz auf
	_vignette = ColorRect.new()
	_vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	_vignette.size = vp
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	# HP-Leiste unten (dezente Kapsel)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.12)
	_bar_bg.position = Vector2(vp.x * 0.2, vp.y * 0.955)
	_bar_bg.size = Vector2(vp.x * 0.6, 14)
	add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(0.3, 0.85, 0.45)
	_bar.position = _bar_bg.position + Vector2(2, 2)
	_bar.size = Vector2(_bar_bg.size.x - 4, _bar_bg.size.y - 4)
	add_child(_bar)

func _physics_process(delta: float) -> void:
	if _iframes > 0.0:
		_iframes -= delta

func reset() -> void:
	hp = max_hp
	_game_over = false
	_iframes = 0.0
	_update_bar()

func iframes_hard_clear() -> void:
	_iframes = 0.0  # für Tests

func take_hit(dmg: int) -> void:
	if _game_over or _iframes > 0.0:
		return
	hp = maxi(hp - dmg, 0)
	_iframes = IFRAMES_SEC
	_update_bar()
	# Sanfte Vignette: kurz aufblitzen, ausfaden (nil-safe in Headless-Tests)
	if _vignette:
		_vignette.color = Color(0.8, 0.1, 0.1, 0.35)
		var t := create_tween()
		t.tween_property(_vignette, "color:a", 0.0, 0.45)
	if hp <= 0:
		_game_over = true
		player_died.emit()

func _update_bar() -> void:
	if _bar:
		_bar.size.x = (_bar_bg.size.x - 4) * float(hp) / float(max_hp)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _bar_bg:
		var vp := get_viewport_rect().size
		_bar_bg.position = Vector2(vp.x * 0.2, vp.y * 0.955)
		_bar.position = _bar_bg.position + Vector2(2, 2)
		_update_bar()