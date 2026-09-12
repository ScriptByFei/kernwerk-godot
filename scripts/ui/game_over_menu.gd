class_name GameOverMenu
extends Control
## Ergebnisanzeige nach dem Absturz.
##
## Hierarchie: die erreichte HOEHE ist der primaere Laufwert, darunter Score und
## Bestwert. Es folgt ein kompakter Statistikblock (PERFECT, RESONANCE,
## OVERLOAD, BESTE KETTE). Der Neustart passiert nur auf Wunsch (NEU STARTEN),
## nicht automatisch.
##
## Aufbau bewusst wie PauseMenu: eigene Flaechen, Eingabe wertet das Menue
## selbst aus, ein Riegel gegen doppelt gemeldete Touch-/Maus-Ereignisse.
## Der zweite Eingabepfad waere im Projekt sonst doppelt vorhanden.

const FONT_BOLD := preload("res://assets/fonts/Rajdhani-Bold.ttf")
const FONT_REGULAR := preload("res://assets/fonts/Rajdhani-Regular.ttf")

signal restart_requested

var score := 0
var best := 0
var is_record := false
var height := 0
var perfect_count := 0
var resonance_count := 0
var overloads := 0
var best_chain := 0

var _locked := false
var _unit := 1.0
var _title_font := 84
var _record_font := 40
var _height_font := 96
var _score_font := 56
var _small_font := 34
var _stat_font := 42
var _stat_label_font := 24
var _row_font := 48
var _panel := Rect2()
var _title_rect := Rect2()
var _record_rect := Rect2()
var _height_rect := Rect2()
var _score_rect := Rect2()
var _best_rect := Rect2()
var _stats_rect := Rect2()
var _restart_rect := Rect2()

# Layout in Design-Einheiten (1080 breit), pro Bildschirm skaliert.
const PANEL_PAD_X := 56.0
const PANEL_PAD_Y := 52.0
const TITLE_FONT := 84.0
const RECORD_FONT := 40.0
const HEIGHT_FONT := 96.0
const SCORE_FONT := 56.0
const SMALL_FONT := 34.0
const STAT_FONT := 42.0
const STAT_LABEL_FONT := 24.0
const ROW_FONT := 48.0
const ROW_HEIGHT := 104.0
const STAT_ROW_HEIGHT := 84.0
const STAT_COLUMNS := 2
const TITLE_TO_RECORD := 6.0
const RECORD_TO_HEIGHT := 10.0
const HEIGHT_TO_SCORE := 12.0
const SCORE_TO_BEST := 18.0
const BEST_TO_STATS := 30.0
const STATS_TO_ROW := 36.0
const PANEL_MAX_WIDTH := 680.0

func _ready() -> void:
	# Bewusst KEINE FULL_RECT-Anchors: unter einer CanvasLayer dimensionieren
	# die hier nicht zuverlaessig (Groesse bleibt 0). PauseMenu loest das
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

## Flaeche der Aktion NEU STARTEN, in Bildschirmkoordinaten.
func restart_rect() -> Rect2:
	return _restart_rect

## Statistikzeilen als Label/Wert/Farb-Tripel. Eine Quelle fuer Layout und
## Zeichnen, damit Beschriftung und Zahl nie auseinanderlaufen.
func stat_entries() -> Array:
	return [
		[JumpConfig.GAME_OVER_STAT_LABELS[0], str(perfect_count), JumpConfig.GAME_OVER_STAT_COLORS[0]],
		[JumpConfig.GAME_OVER_STAT_LABELS[1], str(resonance_count), JumpConfig.GAME_OVER_STAT_COLORS[1]],
		[JumpConfig.GAME_OVER_STAT_LABELS[2], str(overloads), JumpConfig.GAME_OVER_STAT_COLORS[2]],
		[JumpConfig.GAME_OVER_STAT_LABELS[3], str(best_chain), JumpConfig.GAME_OVER_STAT_COLORS[3]],
	]

## Setzt den Eingaberiegel zurueck. MUSS beim erneuten Oeffnen gerufen werden,
## sonst ist die Anzeige nach dem ersten Absturz fuer immer taub.
func reset_lock() -> void:
	_locked = false
	set_process_unhandled_input(true)

func _apply_layout() -> void:
	if size.x <= 0.0:
		return
	_unit = clampf(size.x / 1080.0, 0.25, 1.6)
	# Auf kleinen Flaechen duerfen Schrift und Zeile nicht unter die
	# Daumen-Groesse fallen. Der Stretch-Faktor liefert den echten Massstab
	# zwischen Design- und Geraetepunkten. Gedeckelt, weil er ohne echtes
	# Fenster sinnlos klein ist (headless) und groesser als 1:1 kein Geraet.
	var pixel_scale := clampf(get_viewport().get_stretch_transform().x.length(), 0.2, 1.0)
	_title_font = maxi(roundi(TITLE_FONT * _unit), ceili(22.0 / pixel_scale))
	_record_font = maxi(roundi(RECORD_FONT * _unit), ceili(12.0 / pixel_scale))
	_height_font = maxi(roundi(HEIGHT_FONT * _unit), ceili(24.0 / pixel_scale))
	_score_font = maxi(roundi(SCORE_FONT * _unit), ceili(18.0 / pixel_scale))
	_small_font = maxi(roundi(SMALL_FONT * _unit), ceili(11.0 / pixel_scale))
	_stat_font = maxi(roundi(STAT_FONT * _unit), ceili(14.0 / pixel_scale))
	_stat_label_font = maxi(roundi(STAT_LABEL_FONT * _unit), ceili(10.0 / pixel_scale))
	_row_font = maxi(roundi(ROW_FONT * _unit), ceili(13.0 / pixel_scale))
	var row_height := maxf(ROW_HEIGHT * _unit, 48.0 / pixel_scale)
	var stat_row_height := maxf(STAT_ROW_HEIGHT * _unit, 40.0 / pixel_scale)
	var stat_rows := int(ceil(float(stat_entries().size()) / float(STAT_COLUMNS)))
	var pad_x := PANEL_PAD_X * _unit
	var pad_y := PANEL_PAD_Y * _unit
	var title_h := float(_title_font) * 1.25
	var record_h := float(_record_font) * 1.35
	var height_h := float(_height_font) * 1.2
	var score_h := float(_score_font) * 1.3
	var best_h := float(_small_font) * 1.5
	var panel_w := minf(PANEL_MAX_WIDTH * _unit, size.x - 2.0 * pad_x)
	var panel_h := (
		pad_y * 2.0 + title_h + TITLE_TO_RECORD * _unit + record_h
		+ RECORD_TO_HEIGHT * _unit + height_h
		+ HEIGHT_TO_SCORE * _unit + score_h + SCORE_TO_BEST * _unit + best_h
		+ BEST_TO_STATS * _unit + float(stat_rows) * stat_row_height
		+ STATS_TO_ROW * _unit + row_height
	)
	_panel = Rect2(
		Vector2((size.x - panel_w) * 0.5, maxf(0.0, (size.y - panel_h) * 0.5)),
		Vector2(panel_w, panel_h)
	)
	var inner_x := _panel.position.x + pad_x
	var inner_w := panel_w - 2.0 * pad_x
	var cursor := _panel.position.y + pad_y
	_title_rect = Rect2(inner_x, cursor, inner_w, title_h)
	cursor += title_h + TITLE_TO_RECORD * _unit
	_record_rect = Rect2(inner_x, cursor, inner_w, record_h)
	cursor += record_h + RECORD_TO_HEIGHT * _unit
	_height_rect = Rect2(inner_x, cursor, inner_w, height_h)
	cursor += height_h + HEIGHT_TO_SCORE * _unit
	_score_rect = Rect2(inner_x, cursor, inner_w, score_h)
	cursor += score_h + SCORE_TO_BEST * _unit
	_best_rect = Rect2(inner_x, cursor, inner_w, best_h)
	cursor += best_h + BEST_TO_STATS * _unit
	_stats_rect = Rect2(inner_x, cursor, inner_w, float(stat_rows) * stat_row_height)
	cursor += float(stat_rows) * stat_row_height + STATS_TO_ROW * _unit
	_restart_rect = Rect2(inner_x, cursor, inner_w, row_height)

func _draw() -> void:
	if _panel.size.x <= 0.0:
		return
	# Die eingefrorene Welt bleibt sichtbar, tritt aber eindeutig zurueck.
	draw_rect(Rect2(Vector2.ZERO, size), JumpConfig.PAUSE_DIM_COLOR, true)
	draw_rect(_panel, JumpConfig.PAUSE_PANEL_COLOR, true)
	draw_rect(_panel, JumpConfig.PAUSE_PANEL_BORDER_COLOR, false, maxf(1.0, 1.5 * _unit))
	draw_string(
		FONT_BOLD,
		_title_rect.position + Vector2(0.0, _title_rect.size.y * 0.78),
		JumpConfig.GAME_OVER_TITLE,
		HORIZONTAL_ALIGNMENT_CENTER,
		_title_rect.size.x,
		_title_font,
		JumpConfig.PAUSE_TITLE_COLOR
	)
	# Die Auszeichnung erscheint nur, wenn es einen vorherigen Wert gab. Beim
	# ersten Lauf waere "NEUER BESTWERT" eine leere Auszeichnung.
	if is_record:
		draw_string(
			FONT_BOLD,
			_record_rect.position + Vector2(0.0, _record_rect.size.y * 0.76),
			JumpConfig.GAME_OVER_RECORD_LABEL,
			HORIZONTAL_ALIGNMENT_CENTER,
			_record_rect.size.x,
			_record_font,
			JumpConfig.GAME_OVER_RECORD_COLOR
		)
	# Primaerer Laufwert: die erreichte Hoehe.
	draw_string(
		FONT_REGULAR,
		_height_rect.position + Vector2(0.0, float(_stat_label_font) * 1.1),
		JumpConfig.GAME_OVER_HEIGHT_LABEL,
		HORIZONTAL_ALIGNMENT_CENTER,
		_height_rect.size.x,
		_stat_label_font,
		JumpConfig.PAUSE_SECONDARY_COLOR
	)
	draw_string(
		FONT_BOLD,
		_height_rect.position + Vector2(0.0, _height_rect.size.y * 0.92),
		"%05d" % height,
		HORIZONTAL_ALIGNMENT_CENTER,
		_height_rect.size.x,
		_height_font,
		JumpConfig.PAUSE_TITLE_COLOR
	)
	draw_string(
		FONT_BOLD,
		_score_rect.position + Vector2(0.0, _score_rect.size.y * 0.78),
		"%s %06d" % [JumpConfig.PAUSE_SCORE_LABEL, score],
		HORIZONTAL_ALIGNMENT_CENTER,
		_score_rect.size.x,
		_score_font,
		JumpConfig.PAUSE_SCORE_COLOR
	)
	var best_label := JumpConfig.GAME_OVER_BEST_LABEL
	if best > 0:
		best_label = "%s %06d" % [JumpConfig.GAME_OVER_BEST_LABEL, best]
	draw_string(
		FONT_REGULAR,
		_best_rect.position + Vector2(0.0, _best_rect.size.y * 0.76),
		best_label,
		HORIZONTAL_ALIGNMENT_CENTER,
		_best_rect.size.x,
		_small_font,
		JumpConfig.PAUSE_SECONDARY_COLOR
	)
	_draw_stats()
	_draw_row(_restart_rect, JumpConfig.GAME_OVER_RESTART_LABEL)

## Kompakter Statistikblock: zwei Spalten, Label gedaempft, Zahl farbig.
## Kein neues Panel, keine neue Aktion, keine Animation.
func _draw_stats() -> void:
	var entries := stat_entries()
	var columns := STAT_COLUMNS
	var rows := int(ceil(float(entries.size()) / float(columns)))
	var cell_w := _stats_rect.size.x / float(columns)
	var cell_h := _stats_rect.size.y / float(rows)
	for index in entries.size():
		var column := index % columns
		var row := index / columns
		var cell := Rect2(
			_stats_rect.position + Vector2(float(column) * cell_w, float(row) * cell_h),
			Vector2(cell_w, cell_h)
		)
		draw_string(
			FONT_REGULAR,
			cell.position + Vector2(0.0, float(_stat_label_font) * 1.1),
			entries[index][0],
			HORIZONTAL_ALIGNMENT_CENTER,
			cell.size.x,
			_stat_label_font,
			JumpConfig.PAUSE_SECONDARY_COLOR
		)
		draw_string(
			FONT_BOLD,
			cell.position + Vector2(0.0, cell.size.y * 0.98),
			entries[index][1],
			HORIZONTAL_ALIGNMENT_CENTER,
			cell.size.x,
			_stat_font,
			entries[index][2]
		)

func _draw_row(rect: Rect2, label: String) -> void:
	draw_rect(rect, JumpConfig.PAUSE_ROW_PLATE_COLOR, true)
	var line := maxf(1.0, 1.5 * _unit)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, line)), JumpConfig.PAUSE_ROW_BORDER_COLOR, true)
	draw_rect(
		Rect2(rect.position + Vector2(0.0, rect.size.y - line), Vector2(rect.size.x, line)),
		JumpConfig.PAUSE_ROW_BORDER_COLOR,
		true
	)
	draw_string(
		FONT_BOLD,
		rect.position + Vector2(0.0, rect.size.y * 0.5 + float(_row_font) * 0.36),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		_row_font,
		JumpConfig.PAUSE_TITLE_COLOR
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
	# Ein Tap ausserhalb der Zeile tut bewusst nichts: sonst wuerde ein
	# versehentlicher Tipp neben das Menue sofort neu starten.
	if _restart_rect.has_point(position):
		_choose()

func _choose() -> void:
	# Nach der Entscheidung nimmt das Menue keine Eingabe mehr an. Ein doppelt
	# gemeldeter Touch-/Maus-Event darf nicht zwei Neustarts ausloesen.
	_locked = true
	set_process_unhandled_input(false)
	restart_requested.emit()
