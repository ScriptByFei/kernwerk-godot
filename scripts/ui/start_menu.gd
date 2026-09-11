class_name StartMenu
extends Control
## Screen-fixed reactor overlay. All Controls deliberately ignore input so
## the existing whole-screen unhandled-input path receives mouse AND touch.

const START_MENU_BG := preload("res://assets/jump/reactor_core/start_menu_bg.png")

const FONT_BOLD := preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/Rajdhani-Regular.ttf")

var bg: TextureRect
var title_label: Label
var subtitle_label: Label
var cta_panel: Panel
var cta_label: Label
var _idle_tween: Tween
var _press_tween: Tween
# Tween scalar layout offsets, not positions: resizing also works mid-reveal.
var title_drift := 0.0:
	set(value):
		title_drift = value
		_apply_layout()
var secondary_drift := 0.0:
	set(value):
		secondary_drift = value
		_apply_layout()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_nodes()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	_start_idle_loop()

func _on_viewport_size_changed() -> void:
	size = get_viewport_rect().size
	_apply_layout()
	# Stretch transform and font minimum caches settle after size_changed.
	_apply_layout.call_deferred()

func _build_nodes() -> void:
	bg = TextureRect.new()
	bg.name = "Background"
	# The artwork is authored 1080x1920 portrait and covers the screen directly.
	# It deliberately keeps the reactor area empty, so the live reactor stays
	# the only character during the dissolve (no double silhouette).
	bg.texture = START_MENU_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Chamber atmosphere, not an opaque splash: expose the actual idle reactor.
	bg.modulate.a = 0.32
	bg.self_modulate = Color(0.74, 0.78, 0.82)
	add_child(bg)
	title_label = _make_label("KERNWERK", FONT_BOLD, Color(1.0, 0.965, 0.91))
	# Warm halo instead of a flat grey logo: reads as powered metal and picks up
	# the reactor's amber light. Width is proportional, see _apply_layout.
	title_label.add_theme_color_override("font_outline_color", Color(1.0, 0.55, 0.16, 0.55))
	title_label.add_theme_constant_override("outline_size", 6)
	add_child(title_label)
	subtitle_label = _make_label("RESONANZSPRUNG", FONT_REGULAR, Color(0.62, 0.70, 0.72))
	add_child(subtitle_label)
	# The old texture contains baked-in START lettering. Use a simple console
	# plate instead; keep the source asset untouched and render exactly one CTA.
	cta_panel = Panel.new()
	cta_panel.name = "CtaPanel"
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.055, 0.085, 0.10, 0.32)
	plate.border_color = Color(0.38, 0.47, 0.48, 0.80)
	plate.set_border_width_all(0)
	plate.border_width_top = 1
	plate.border_width_bottom = 1
	plate.set_corner_radius_all(0)
	cta_panel.add_theme_stylebox_override("panel", plate)
	cta_panel.self_modulate = Color(0.88, 0.91, 0.90)
	add_child(cta_panel)
	cta_label = _make_label("REAKTOR STARTEN", FONT_BOLD, Color(0.88, 0.92, 0.89))
	cta_panel.add_child(cta_label)
	for node: Control in [bg, title_label, subtitle_label, cta_panel, cta_label]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_layout() -> void:
	if title_label == null:
		return
	# keep_width creates a variable virtual height; short landscape layouts
	# scale their typography/CTA down rather than pushing anything off-screen.
	var unit := minf(size.x / 1080.0, size.y / 1500.0)
	# Typography and hairlines must survive the existing landscape letterbox.
	var pixel_scale := maxf(0.01, get_viewport().get_stretch_transform().x.length())
	var title_font := maxi(roundi(100.0 * unit), ceili(22.0 / pixel_scale))
	var subtitle_font := maxi(roundi(28.0 * unit), ceili(9.0 / pixel_scale))
	var cta_font := maxi(roundi(48.0 * unit), ceili(12.0 / pixel_scale))
	var margin := 64.0 * unit
	bg.position = Vector2.ZERO
	bg.size = size
	title_label.add_theme_font_size_override("font_size", title_font)
	title_label.add_theme_constant_override(
		"outline_size", maxi(1, roundi(title_font * JumpConfig.START_TITLE_GLOW_RATIO)))
	subtitle_label.add_theme_font_size_override("font_size", subtitle_font)
	cta_label.add_theme_font_size_override("font_size", cta_font)
	# A prior tiny/headless viewport may have expanded Label minimum sizes.
	# Reset after font changes so rotation can shrink as well as grow.
	for label: Label in [title_label, subtitle_label, cta_label]:
		label.reset_size()
	title_label.position = Vector2(margin, minf(40.0 / pixel_scale, size.y * 0.065) + title_drift * unit)
	title_label.size = Vector2(size.x - 2.0 * margin, title_font * 1.26)
	subtitle_label.position = Vector2(margin, title_label.position.y + title_label.size.y + 2.0 * unit)
	subtitle_label.size = Vector2(size.x - 2.0 * margin, subtitle_font * 1.5)
	# Subtitle follows the secondary fade/drift, independent from title.
	subtitle_label.position.y += (secondary_drift - title_drift) * unit
	cta_panel.size = Vector2(maxf(580.0 * unit, cta_label.get_minimum_size().x + 64.0 * unit), maxf(112.0 * unit, 44.0 / pixel_scale))
	var plate := cta_panel.get_theme_stylebox("panel") as StyleBoxFlat
	plate.border_width_top = ceili(1.0 / pixel_scale)
	plate.border_width_bottom = ceili(1.0 / pixel_scale)
	cta_panel.position = Vector2((size.x - cta_panel.size.x) * 0.5, size.y * 0.62 - cta_panel.size.y * 0.5 + secondary_drift * unit)
	cta_panel.pivot_offset = cta_panel.size * 0.5
	cta_label.position = Vector2.ZERO
	cta_label.size = cta_panel.size

func _make_label(text: String, font: FontFile, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _start_idle_loop() -> void:
	_idle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var half_period := JumpConfig.START_IDLE_PERIOD * 0.5
	# Only the chamber light breathes. The approved sprite supplies core energy.
	_idle_tween.tween_property(bg, "self_modulate", Color(0.78, 0.82, 0.86), half_period)
	_idle_tween.tween_property(bg, "self_modulate", Color(0.74, 0.78, 0.82), half_period)

func start_press_feedback() -> void:
	stop_idle()
	# Immediate electrical acknowledgement; no mechanical button punch.
	cta_panel.self_modulate = Color(1.12, 1.10, 1.02)
	_press_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(cta_panel, "self_modulate", Color.WHITE, JumpConfig.START_PRESS_FEEDBACK)

func stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null

func _exit_tree() -> void:
	stop_idle()
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
