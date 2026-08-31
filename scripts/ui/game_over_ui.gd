class_name GameOverUI
extends Control
## Game-Over-Overlay: Score, Kills, Restart-Button. Restart ohne Seiten-Reload
## (Szene wird per Restart-Signal von Game neu aufgebaut).

signal restart_requested

var _score_label: Label
var _kills_label: Label

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	# Abdunkelung
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = size
	add_child(dim)
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0
	var title := Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	title.position = Vector2(cx - 240, cy - 260)
	title.size = Vector2(480, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 42)
	_score_label.position = Vector2(cx - 240, cy - 80)
	_score_label.size = Vector2(480, 60)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score_label)
	_kills_label = Label.new()
	_kills_label.add_theme_font_size_override("font_size", 40)
	_kills_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	_kills_label.position = Vector2(cx - 240, cy - 180)
	_kills_label.size = Vector2(480, 50)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kills_label)
	var btn := Button.new()
	btn.text = "RESTART"
	btn.add_theme_font_size_override("font_size", 44)
	btn.position = Vector2(cx - 140, cy + 80)
	btn.size = Vector2(280, 90)
	btn.pressed.connect(func(): restart_pressed.emit())
	add_child(btn)
	# Tap irgendwo außer dem Button restartet auch:
	gui_input.connect(_on_gui)

signal restart_pressed

func _on_gui(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		restart_pressed.emit()

func show_stats(score: int, kills: int) -> void:
	_score_label.text = "SCORE: %d" % score
	_kills_label.text = "ENEMIES DEFEATED: %d" % kills
	visible = true