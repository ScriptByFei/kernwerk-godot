class_name PauseUI
extends CanvasLayer
## Leichtes Pause-Overlay für Escape und automatisches Browser-Focus-Pause.

var _safe_margin: MarginContainer

func _ready() -> void:
	layer = UiLayout.PAUSE_LAYER
	_build_ui()
	visible = false
	get_viewport().size_changed.connect(_layout_ui)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_safe_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe_margin.add_child(center)

	var label := Label.new()
	label.text = "PAUSED\nESC TO RESUME"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 54)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	center.add_child(label)
	_layout_ui()

func _layout_ui() -> void:
	if _safe_margin:
		UiLayout.apply_safe_margins(_safe_margin, get_viewport().get_visible_rect().size)

func show_paused(paused: bool) -> void:
	visible = paused
