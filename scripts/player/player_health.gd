class_name PlayerHealth
extends CanvasLayer
## Spieler-HP-Visualisierung: sichere Leiste unten + Vignette bei Schaden.
## GameManager bleibt die einzige Quelle für HP, i-Frames und Game Over.

signal player_died

var hp := GameConfig.MAX_HEALTH
var max_hp := GameConfig.MAX_HEALTH
var _root: Control
var _vignette: ColorRect
var _bar: ColorRect
var _bar_bg: ColorRect
var _game_over := false
var _game_manager: GameManager
var _screen_shake: Node
var _sfx

func _ready() -> void:
	layer = UiLayout.DAMAGE_LAYER
	_build_ui()
	get_viewport().size_changed.connect(_layout_ui)

func setup(game_manager: GameManager, screen_shake: Node = null, sfx = null) -> void:
	_game_manager = game_manager
	_screen_shake = screen_shake
	_sfx = sfx
	hp = game_manager.player_hp
	max_hp = GameConfig.MAX_HEALTH
	game_manager.player_health_changed.connect(_on_health_changed)
	game_manager.game_over.connect(_on_game_over)
	_update_bar()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.14)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(0.3, 0.85, 0.45)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)
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
	var took_damage := _game_manager.damage_player(dmg)
	if took_damage and _game_manager.player_hp > 0 and _screen_shake:
		_screen_shake.shake(8.0, 0.18)
	if took_damage and _sfx:
		_sfx.play("player_hit")
	return took_damage

func _on_health_changed(new_hp: int, new_max_hp: int) -> void:
	hp = new_hp
	max_hp = new_max_hp
	_update_bar()
	if _vignette:
		_vignette.color = Color(0.8, 0.1, 0.1, 0.35)
		var tween := create_tween()
		tween.tween_property(_vignette, "color:a", 0.0, 0.45)

func _on_game_over() -> void:
	_game_over = true
	player_died.emit()

func _update_bar() -> void:
	if _bar and _bar_bg:
		var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
		_bar.size.x = (_bar_bg.size.x - 6.0) * ratio

func _layout_ui() -> void:
	if not _bar_bg:
		return
	var rect := UiLayout.content_rect(get_viewport().get_visible_rect().size)
	var width := minf(rect.size.x * 0.62, 650.0)
	var x := rect.position.x + (rect.size.x - width) * 0.5
	var y := rect.end.y - 28.0
	_bar_bg.position = Vector2(x, y)
	_bar_bg.size = Vector2(width, 20)
	_bar.position = _bar_bg.position + Vector2(3, 3)
	_bar.size.y = 14
	_update_bar()
