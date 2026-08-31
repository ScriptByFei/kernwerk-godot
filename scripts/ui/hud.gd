class_name Hud
extends CanvasLayer
## Minimales HUD unten: текущые Werte (Damage, Fire Rate, Soldiers).
## Oben: Score + Kills. Absichtlich reduziert — Gameplay bleibt Kern.

var _stats: PlayerStats
var _game: GameManager

var _score_label: Label
var _dmg_label: Label
var _rate_label: Label
var _sold_label: Label

func setup(stats: PlayerStats, game: GameManager) -> void:
	_stats = stats
	_game = game
	_build()
	_stats.stats_changed.connect(_refresh)
	_game.score_changed.connect(_on_score)
	_game.kills_changed.connect(_on_score)
	_refresh()

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	_score_label = _make_label(Vector2(24, 24), 40)
	_dmg_label = _make_label(Vector2(24, vp.y - 110), 26)
	_rate_label = _make_label(Vector2(24, vp.y - 76), 26)
	_sold_label = _make_label(Vector2(24, vp.y - 42), 26)
	_on_score()

func _make_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	add_child(l)
	return l

func _on_score(_s: int = 0) -> void:
	_score_label.text = "SCORE %d   KILLS %d" % [_game.score, _game.kills]

func _refresh() -> void:
	_dmg_label.text = "DMG %d" % _stats.damage
	_rate_label.text = "RATE %.1f" % _stats.fire_rate
	_sold_label.text = "SOLDIERS %d" % _stats.soldiers

func _notification(what: int) -> void:
	# Labels mit negativen y wären oben — fixiere unten:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		var vp := get_viewport().get_visible_rect().size
		_dmg_label.position = Vector2(24, vp.y - 110)
		_rate_label.position = Vector2(24, vp.y - 76)
		_sold_label.position = Vector2(24, vp.y - 42)