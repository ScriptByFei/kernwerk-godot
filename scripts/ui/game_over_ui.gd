class_name GameOverUI
extends CanvasLayer
## Responsives Game-Over-Overlay. Als oberste CanvasLayer verdeckt es die
## eingefrorene Spielwelt zuverlässig und bleibt bei Viewport-Resizes zentriert.

signal restart_pressed

var _root: Control
var _safe_margin: MarginContainer
var _score_label: Label
var _kills_label: Label

func _ready() -> void:
	layer = UiLayout.MODAL_LAYER
	_build_ui()
	visible = false
	get_viewport().size_changed.connect(_layout_ui)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.04, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_safe_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe_margin.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 560)
	panel.add_theme_stylebox_override("panel", UiLayout.panel_style(Color(1.0, 0.3, 0.35, 0.7)))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	panel.add_child(column)

	column.add_child(_make_label("GAME OVER", 76, Color(1, 0.35, 0.38)))
	_kills_label = _make_label("", 36, Color(0.78, 0.84, 1.0))
	column.add_child(_kills_label)
	_score_label = _make_label("", 44, Color.WHITE)
	column.add_child(_score_label)

	var button := Button.new()
	button.text = "RESTART"
	button.custom_minimum_size = Vector2(320, 96)
	button.add_theme_font_size_override("font_size", 40)
	button.pressed.connect(func(): restart_pressed.emit())
	column.add_child(button)
	_layout_ui()

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _layout_ui() -> void:
	if _safe_margin:
		UiLayout.apply_safe_margins(_safe_margin, get_viewport().get_visible_rect().size)

func show_stats(score: int, kills: int) -> void:
	_score_label.text = "SCORE: %d" % score
	_kills_label.text = "ENEMIES DEFEATED: %d" % kills
	visible = true
