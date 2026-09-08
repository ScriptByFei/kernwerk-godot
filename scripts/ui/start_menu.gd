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

func _build_nodes() -> void:
	bg = TextureRect.new()
	bg.name = "Background"
	# Reuse the upper chamber, not its large painted reactor: the live reactor
	# remains the only character during the dissolve (no double silhouette).
	var chamber := AtlasTexture.new()
	chamber.atlas = START_MENU_BG
	chamber.region = Rect2(0, 0, 1080, 760)
	bg.texture = chamber
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The live world remains rendered and faintly visible underneath.
	bg.modulate.a = 0.70
	bg.self_modulate = Color(0.64, 0.68, 0.72)
	add_child(bg)
	title_label = _make_label("KERNWERK", FONT_BOLD, Color(0.83, 0.88, 0.87))
	add_child(title_label)
	subtitle_label = _make_label("RESONANZSPRUNG", FONT_REGULAR, Color(0.53, 0.65, 0.67))
	add_child(subtitle_label)
	# The old texture contains baked-in START lettering. Use a simple console
	# plate instead; keep the source asset untouched and render exactly one CTA.
	cta_panel = Panel.new()
	cta_panel.name = "CtaPanel"
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.055, 0.085, 0.10, 0.97)
	plate.border_color = Color(0.49, 0.57, 0.56)
	plate.set_border_width_all(2)
	plate.border_width_bottom = 5
	plate.set_corner_radius_all(6)
	cta_panel.add_theme_stylebox_override("panel", plate)
	cta_panel.self_modulate = Color(0.82, 0.85, 0.84)
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
	var margin := 64.0 * unit
	bg.position = Vector2.ZERO
	bg.size = size
	title_label.add_theme_font_size_override("font_size", maxi(1, roundi(118.0 * unit)))
	subtitle_label.add_theme_font_size_override("font_size", maxi(1, roundi(38.0 * unit)))
	cta_label.add_theme_font_size_override("font_size", maxi(1, roundi(40.0 * unit)))
	title_label.position = Vector2(margin, size.y * 0.20 + title_drift * unit)
	title_label.size = Vector2(size.x - 2.0 * margin, 150.0 * unit)
	subtitle_label.position = Vector2(margin, title_label.position.y + 146.0 * unit)
	subtitle_label.size = Vector2(size.x - 2.0 * margin, 58.0 * unit)
	# Subtitle follows the secondary fade/drift, independent from title.
	subtitle_label.position.y += (secondary_drift - title_drift) * unit
	cta_panel.size = Vector2(520.0, 150.0) * unit
	cta_panel.position = Vector2((size.x - cta_panel.size.x) * 0.5, size.y * 0.82 - cta_panel.size.y * 0.5 + secondary_drift * unit)
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
	_idle_tween.tween_property(cta_panel, "scale", Vector2.ONE * 1.012, half_period)
	_idle_tween.parallel().tween_property(bg, "self_modulate", Color(0.68, 0.72, 0.76), half_period)
	_idle_tween.tween_property(cta_panel, "scale", Vector2.ONE, half_period)
	_idle_tween.parallel().tween_property(bg, "self_modulate", Color(0.64, 0.68, 0.72), half_period)

func start_press_feedback() -> void:
	stop_idle()
	cta_panel.scale = Vector2.ONE * 0.98
	cta_panel.self_modulate = Color(1.12, 1.10, 1.02)
	_press_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(cta_panel, "scale", Vector2.ONE, JumpConfig.START_PRESS_FEEDBACK)
	_press_tween.parallel().tween_property(cta_panel, "self_modulate", Color.WHITE, JumpConfig.START_PRESS_FEEDBACK)

func stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null

func _exit_tree() -> void:
	stop_idle()
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
