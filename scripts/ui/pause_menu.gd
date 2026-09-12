class_name PauseMenu
extends Control
## Pausenueberlagerung: haelt das Spiel an und bietet WEITER sowie NEU STARTEN.
##
## Eingaben wertet das Menue selbst aus, in derselben Sprache wie die Steuerung
## (Tap gegen gezeichnete Flaechen). Eigene Control-Kinder mit eigenem
## Mausfilter waeren der zweite Eingabepfad im Projekt und wuerden je nach
## Geraet doppelt feuern.
##
## Der `_locked`-Riegel ist wichtig: Touch erzeugt je nach Plattform zusaetzlich
## ein Maus-Ereignis. Ohne den Riegel koennte ein einziger Fingertipp beide
## Aktionen ausloesen.

const FONT_BOLD := preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/Rajdhani-Regular.ttf")

signal resume_requested
signal restart_requested

var score := 0

var _locked := false
var _unit := 1.0
var _title_font := 88
var _score_font := 40
var _row_font := 48
var _panel := Rect2()
var _title_rect := Rect2()
var _score_rect := Rect2()
var _resume_rect := Rect2()
var _restart_rect := Rect2()

# Layout in Design-Einheiten (1080 breit) und wird pro Bildschirm skaliert.
const PANEL_PAD_X := 56.0
const PANEL_PAD_Y := 52.0
const TITLE_FONT := 88.0
const SCORE_FONT := 40.0
const ROW_FONT := 48.0
const ROW_HEIGHT := 104.0
const ROW_GAP := 22.0
const TITLE_TO_SCORE := 4.0
const SCORE_TO_ROWS := 40.0
const PANEL_MAX_WIDTH := 680.0

func _ready() -> void:
	# Bewusst KEINE FULL_RECT-Anchors: unter einer CanvasLayer dimensionieren
	# die hier nicht zuverlaessig (Groesse bleibt 0). Das StartMenu loest das
	# genauso — eigene Groesse setzen, dann stimmt die Flaeche auch headless.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	size = get_viewport_rect().size
	_apply_layout()
	# Stretch-Transform und Schrift-Minima setzen sich erst nach size_changed.
	_apply_layout.call_deferred()
	queue_redraw()

## Flaeche der Aktion WEITER, in Bildschirmkoordinaten.
func resume_rect() -> Rect2:
	return _resume_rect

## Flaeche der Aktion NEU STARTEN, in Bildschirmkoordinaten.
func restart_rect() -> Rect2:
	return _restart_rect

func _apply_layout() -> void:
	if size.x <= 0.0:
		return
	_unit = clampf(size.x / 1080.0, 0.25, 1.6)
	# Auf kleinen Flaechen duerfen Schrift und Zeilen nicht unter die
	# Daumen-Groesse fallen. Der Stretch-Faktor liefert den echten Massstab
	# zwischen Design- und Geraetepunkten.
	#
	# Gedeckelt: ohne echtes Fenster (headless, offscreen) ist der Faktor
	# sinnlos klein und der Mindestwert wuerde auf ein Vielfaches anschwellen.
	# Nach oben auf 1.0 begrenzt, weil groesser als 1:1 kein Geraet ist.
	var pixel_scale := clampf(get_viewport().get_stretch_transform().x.length(), 0.2, 1.0)
	_title_font = maxi(roundi(TITLE_FONT * _unit), ceili(22.0 / pixel_scale))
	_score_font = maxi(roundi(SCORE_FONT * _unit), ceili(11.0 / pixel_scale))
	_row_font = maxi(roundi(ROW_FONT * _unit), ceili(13.0 / pixel_scale))
	# Trefferflaeche: mindestens 48 Geraetepunkte hoch, sonst ist die Zeile auf
	# einem Telefon kein verlaessliches Ziel.
	var row_height := maxf(ROW_HEIGHT * _unit, 48.0 / pixel_scale)
	var row_gap := ROW_GAP * _unit
	var pad_x := PANEL_PAD_X * _unit
	var pad_y := PANEL_PAD_Y * _unit
	var title_h := float(_title_font) * 1.25
	var score_h := float(_score_font) * 1.4
	var panel_w := minf(PANEL_MAX_WIDTH * _unit, size.x - 2.0 * pad_x)
	var panel_h := (
		pad_y * 2.0 + title_h + TITLE_TO_SCORE * _unit + score_h
		+ SCORE_TO_ROWS * _unit + row_height * 2.0 + row_gap
	)
	_panel = Rect2(
		Vector2((size.x - panel_w) * 0.5, (size.y - panel_h) * 0.5),
		Vector2(panel_w, panel_h)
	)
	var inner_x := _panel.position.x + pad_x
	var inner_w := panel_w - 2.0 * pad_x
	var cursor := _panel.position.y + pad_y
	_title_rect = Rect2(inner_x, cursor, inner_w, title_h)
	cursor += title_h + TITLE_TO_SCORE * _unit
	_score_rect = Rect2(inner_x, cursor, inner_w, score_h)
	cursor += score_h + SCORE_TO_ROWS * _unit
	_resume_rect = Rect2(inner_x, cursor, inner_w, row_height)
	cursor += row_height + row_gap
	_restart_rect = Rect2(inner_x, cursor, inner_w, row_height)

func _draw() -> void:
	if _panel.size.x <= 0.0:
		return
	# Das Spiel bleibt sichtbar, ist aber eindeutig in den Hintergrund getreten.
	draw_rect(Rect2(Vector2.ZERO, size), JumpConfig.PAUSE_DIM_COLOR, true)
	draw_rect(_panel, JumpConfig.PAUSE_PANEL_COLOR, true)
	draw_rect(_panel, JumpConfig.PAUSE_PANEL_BORDER_COLOR, false, maxf(1.0, 1.5 * _unit))
	draw_string(
		FONT_BOLD,
		_title_rect.position + Vector2(0.0, _title_rect.size.y * 0.78),
		JumpConfig.PAUSE_TITLE,
		HORIZONTAL_ALIGNMENT_CENTER,
		_title_rect.size.x,
		_title_font,
		JumpConfig.PAUSE_TITLE_COLOR
	)
	draw_string(
		FONT_REGULAR,
		_score_rect.position + Vector2(0.0, _score_rect.size.y * 0.75),
		"%s %06d" % [JumpConfig.PAUSE_SCORE_LABEL, score],
		HORIZONTAL_ALIGNMENT_CENTER,
		_score_rect.size.x,
		_score_font,
		JumpConfig.PAUSE_SCORE_COLOR
	)
	_draw_row(_resume_rect, JumpConfig.PAUSE_RESUME_LABEL, true)
	_draw_row(_restart_rect, JumpConfig.PAUSE_RESTART_LABEL, false)

func _draw_row(rect: Rect2, label: String, primary: bool) -> void:
	draw_rect(rect, JumpConfig.PAUSE_ROW_PLATE_COLOR, true)
	var line := maxf(1.0, 1.5 * _unit)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, line)), JumpConfig.PAUSE_ROW_BORDER_COLOR, true)
	draw_rect(
		Rect2(rect.position + Vector2(0.0, rect.size.y - line), Vector2(rect.size.x, line)),
		JumpConfig.PAUSE_ROW_BORDER_COLOR,
		true
	)
	var color := JumpConfig.PAUSE_TITLE_COLOR if primary else JumpConfig.PAUSE_SECONDARY_COLOR
	draw_string(
		FONT_BOLD,
		rect.position + Vector2(0.0, rect.size.y * 0.5 + float(_row_font) * 0.36),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		_row_font,
		color
	)

func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_tap(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_tap(event.position)

func _handle_tap(position: Vector2) -> void:
	# Ein Tap ausserhalb beider Zeilen tut bewusst nichts. Sonst wuerde ein
	# versehentlicher Tipp neben das Menue das Spiel fortsetzen.
	if _resume_rect.has_point(position):
		_choose(true)
	elif _restart_rect.has_point(position):
		_choose(false)

func _choose(resume: bool) -> void:
	# Nach der ersten Entscheidung nimmt das Menue keine Eingabe mehr an. Ein
	# doppelt gemeldeter Touch/Maus-Event darf nicht zwei Aktionen ausloesen:
	# ein zweiter Neustart wuerde die frisch angelegte Szene wieder abraeumen.
	_locked = true
	set_process_unhandled_input(false)
	if resume:
		resume_requested.emit()
	else:
		restart_requested.emit()
