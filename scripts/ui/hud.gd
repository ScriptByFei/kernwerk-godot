class_name Hud
extends CanvasLayer
## Responsives HUD innerhalb des gemeinsamen Safe-Area-Inhaltsbereichs.

var _stats: PlayerStats
var _game: GameManager
var _wave_manager: WaveManager

var _score_label: Label
var _wave_label: Label
var _dmg_label: Label
var _rate_label: Label
var _sold_label: Label

func setup(stats: PlayerStats, game: GameManager) -> void:
	layer = UiLayout.HUD_LAYER
	_stats = stats
	_game = game
	_build()
	_stats.stats_changed.connect(_refresh)
	_game.score_changed.connect(_on_score)
	_game.kills_changed.connect(_on_score)
	get_viewport().size_changed.connect(_layout)
	_refresh()

func attach_wave_manager(wave_manager: WaveManager) -> void:
	_wave_manager = wave_manager
	_wave_manager.wave_started.connect(_on_wave_started)
	if _wave_manager.current_wave > 0:
		_on_wave_started(_wave_manager.current_wave)

func _build() -> void:
	_score_label = _make_label(40)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wave_label = _make_label(38)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dmg_label = _make_label(26)
	_rate_label = _make_label(26)
	_sold_label = _make_label(26)
	_on_score()
	_layout()

func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	add_child(label)
	return label

func _on_score(_value: int = 0) -> void:
	_score_label.text = "SCORE %d   KILLS %d" % [_game.score, _game.kills]

func _on_wave_started(wave: int) -> void:
	_wave_label.text = "WAVE %d/%d" % [wave, WaveData.wave_count()]

func _refresh() -> void:
	_dmg_label.text = "DMG %d" % _stats.damage
	_rate_label.text = "RATE %.1f" % _stats.fire_rate
	_sold_label.text = "SOLDIERS %d" % _stats.soldiers

func _layout() -> void:
	if not _score_label:
		return
	var rect := UiLayout.content_rect(get_viewport().get_visible_rect().size)
	_score_label.position = rect.position
	_score_label.size = Vector2(rect.size.x * 0.68, 56)
	_wave_label.position = Vector2(rect.position.x + rect.size.x * 0.68, rect.position.y)
	_wave_label.size = Vector2(rect.size.x * 0.32, 56)
	var bottom_y := rect.end.y - 132.0
	_dmg_label.position = Vector2(rect.position.x, bottom_y)
	_rate_label.position = Vector2(rect.position.x, bottom_y + 36.0)
	_sold_label.position = Vector2(rect.position.x, bottom_y + 72.0)
