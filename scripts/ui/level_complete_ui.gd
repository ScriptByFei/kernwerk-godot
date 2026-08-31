class_name LevelCompleteUI
extends Control
## Level-Complete-Overlay: Score/Kills + Continue/Retry. Erscheint nach letzter Welle.

signal continue_pressed
signal retry_pressed

var _score_label: Label
var _kills_label: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = size
	add_child(dim)
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var title := Label.new()
	title.text = "LEVEL COMPLETE"
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	title.position = Vector2(cx - 300, cy - 240)
	title.size = Vector2(600, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_kills_label = Label.new()
	_kills_label.add_theme_font_size_override("font_size", 40)
	_kills_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	_kills_label.position = Vector2(cx - 240, cy - 120)
	_kills_label.size = Vector2(480, 50)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kills_label)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 42)
	_score_label.position = Vector2(cx - 240, cy - 130)
	_score_label.size = Vector2(480, 60)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score_label)
	var cont := Button.new()
	cont.text = "CONTINUE"
	cont.add_theme_font_size_override("font_size", 40)
	cont.position = Vector2(cx - 230, cy + 60)
	cont.size = Vector2(220, 84)
	cont.pressed.connect(func(): continue_pressed.emit())
	add_child(cont)
	var retry := Button.new()
	retry.text = "RETRY"
	retry.add_theme_font_size_override("font_size", 40)
	retry.position = Vector2(cx + 10, cy + 60)
	retry.size = Vector2(220, 84)
	retry.pressed.connect(func(): retry_pressed.emit())
	add_child(retry)

func show_stats(score: int, kills: int) -> void:
	_score_label.text = "SCORE: %d" % score
	_kills_label.text = "ENEMIES DEFEATED: %d" % kills
	visible = true