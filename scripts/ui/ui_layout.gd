class_name UiLayout
extends RefCounted
## Gemeinsame responsive UI-Helfer. Alle HUD- und Overlay-Flächen verwenden
## denselben sicheren Inhaltsbereich statt eigener Rand-Magie.

const HUD_LAYER := 20
const DAMAGE_LAYER := 30
const PAUSE_LAYER := 90
const MODAL_LAYER := 100

const COLOR_PANEL := Color(0.055, 0.065, 0.105, 0.96)
const COLOR_PANEL_BORDER := Color(0.35, 0.42, 0.62, 0.55)

static func content_rect(
		viewport_size: Vector2,
		window_size: Vector2 = Vector2.ZERO,
		display_safe_area: Rect2 = Rect2()) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)

	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		window_size = viewport_size

	if display_safe_area.size.x <= 0.0 or display_safe_area.size.y <= 0.0:
		display_safe_area = Rect2(DisplayServer.get_display_safe_area())
	if display_safe_area.size.x <= 0.0 or display_safe_area.size.y <= 0.0:
		display_safe_area = Rect2(Vector2.ZERO, window_size)

	var scale := Vector2(viewport_size.x / window_size.x, viewport_size.y / window_size.y)
	var safe_end := display_safe_area.position + display_safe_area.size
	var left := maxf(GameConfig.UI_SAFE_SIDE, display_safe_area.position.x * scale.x)
	var top := maxf(GameConfig.UI_SAFE_TOP, display_safe_area.position.y * scale.y)
	var right := maxf(GameConfig.UI_SAFE_SIDE, (window_size.x - safe_end.x) * scale.x)
	var bottom := maxf(GameConfig.UI_SAFE_BOTTOM, (window_size.y - safe_end.y) * scale.y)

	left = minf(left, viewport_size.x * 0.25)
	right = minf(right, viewport_size.x * 0.25)
	top = minf(top, viewport_size.y * 0.2)
	bottom = minf(bottom, viewport_size.y * 0.2)
	return Rect2(
		Vector2(left, top),
		Vector2(maxf(viewport_size.x - left - right, 0.0), maxf(viewport_size.y - top - bottom, 0.0))
	)

static func apply_safe_margins(container: MarginContainer, viewport_size: Vector2) -> void:
	var rect := content_rect(viewport_size)
	container.add_theme_constant_override("margin_left", roundi(rect.position.x))
	container.add_theme_constant_override("margin_top", roundi(rect.position.y))
	container.add_theme_constant_override("margin_right", roundi(viewport_size.x - rect.end.x))
	container.add_theme_constant_override("margin_bottom", roundi(viewport_size.y - rect.end.y))

static func panel_style(border_color: Color = COLOR_PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(28)
	style.content_margin_left = 48.0
	style.content_margin_top = 42.0
	style.content_margin_right = 48.0
	style.content_margin_bottom = 42.0
	return style
