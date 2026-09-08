class_name StartMenu
extends Node2D
## Screen-fixed start menu overlay. Drawn in screen space on a CanvasLayer so it
## stays centered regardless of the game camera position.

const START_MENU_BG := preload("res://assets/jump/reactor_core/start_menu_bg.png")
const START_BUTTON := preload("res://assets/jump/reactor_core/start_button.png")

func _ready() -> void:
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		queue_redraw()

func _draw() -> void:
	var screen_rect := get_viewport().get_visible_rect()
	# Background artwork fills the whole screen.
	draw_texture_rect(START_MENU_BG, screen_rect, false)
	var center := screen_rect.position + screen_rect.size * 0.5
	var full_width := screen_rect.size.x
	# Title
	draw_string(
		ThemeDB.fallback_font,
		screen_rect.position + Vector2(0.0, center.y - 220.0),
		"KERNWERK",
		HORIZONTAL_ALIGNMENT_CENTER,
		full_width,
		96,
		Color(0.72, 1.0, 0.92)
	)
	draw_string(
		ThemeDB.fallback_font,
		screen_rect.position + Vector2(0.0, center.y - 140.0),
		"RESONANZSPRUNG",
		HORIZONTAL_ALIGNMENT_CENTER,
		full_width,
		48,
		Color(0.16, 0.52, 0.58)
	)
	# Start button artwork (400x140), centered below the title.
	var button_size := Vector2(400.0, 140.0)
	var button_center := center + Vector2(0.0, 120.0)
	draw_texture_rect(
		START_BUTTON,
		Rect2(button_center - button_size * 0.5, button_size),
		false
	)
	# Hint
	draw_string(
		ThemeDB.fallback_font,
		screen_rect.position + Vector2(0.0, center.y + 300.0),
		"Tippe zum Starten",
		HORIZONTAL_ALIGNMENT_CENTER,
		full_width,
		32,
		Color(0.72, 0.82, 0.86)
	)
