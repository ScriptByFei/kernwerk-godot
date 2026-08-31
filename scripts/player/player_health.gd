class_name PlayerHealth
extends Node2D
## Spieler-HP-Visualisierung: dezente Leiste unten + rote Vignette bei Schaden.
## GameManager ist die einzige Quelle für HP, i-Frames und Game-Over-Zustand.

signal player_died

var hp := GameConfig.MAX_HEALTH
var max_hp := GameConfig.MAX_HEALTH
var _vignette: ColorRect
var _bar: ColorRect
var _bar_bg: ColorRect
var _game_over := false
var _game_manager: GameManager
var _last_viewport_size := Vector2.ZERO

func _ready() -> void:
	_build_ui()
	_last_viewport_size = get_viewport_rect().size

func setup(game_manager: GameManager) -> void:
	_game_manager = game_manager
	hp = game_manager.player_hp
	max_hp = GameConfig.MAX_HEALTH
	game_manager.player_health_changed.connect(_on_health_changed)
	game_manager.game_over.connect(_on_game_over)
	_update_bar()

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

func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_layout_ui()

func reset() -> void:
	_game_over = false
	if _game_manager:
		hp = _game_manager.player_hp
	_update_bar()

func iframes_hard_clear() -> void:
	if _game_manager:
		_game_manager.clear_iframes()

func take_hit(dmg: int) -> bool:
	if _game_manager == null or _game_over:
		return false
	return _game_manager.damage_player(dmg)

func _on_health_changed(new_hp: int, new_max_hp: int) -> void:
	hp = new_hp
	max_hp = new_max_hp
	_update_bar()
	if _vignette:
		_vignette.color = Color(0.8, 0.1, 0.1, 0.35)
		var t := create_tween()
		t.tween_property(_vignette, "color:a", 0.0, 0.45)

func _on_game_over() -> void:
	_game_over = true
	player_died.emit()

func _update_bar() -> void:
	if _bar and _bar_bg:
		_bar.size.x = (_bar_bg.size.x - 4) * float(hp) / float(max_hp)

func _layout_ui() -> void:
	if not _bar_bg:
		return
	var vp := get_viewport_rect().size
	_vignette.size = vp
	_bar_bg.position = Vector2(vp.x * 0.2, vp.y * 0.955)
	_bar_bg.size = Vector2(vp.x * 0.6, 14)
	_bar.position = _bar_bg.position + Vector2(2, 2)
	_update_bar()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _bar_bg:
		_layout_ui()
