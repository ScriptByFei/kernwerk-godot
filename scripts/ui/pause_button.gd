class_name PauseButton
extends Control
## Pausenknopf oben rechts im Spiel.
##
## Bewusst reine Anzeige (mouse_filter IGNORE): den Tap wertet das Spiel aus.
## Dadurch laeuft die Pause durch denselben Eingabepfad wie die Steuerung und
## ein Finger kann nie gleichzeitig steuern und pausieren.
##
## `rect_for()` ist die einzige Quelle fuer Flaeche und Zeichnung. Zwei getrennte
## Rechnungen wuerden frueher oder spaeter auseinanderdriften und der sichtbare
## Knopf waere nicht mehr die Flaeche, die tatsaechlich reagiert.

func _ready() -> void:
	# Bewusst KEINE FULL_RECT-Anchors: unter einer CanvasLayer dimensionieren
	# die hier nicht zuverlaessig (Groesse bleibt 0). Das StartMenu loest das
	# genauso — eigene Groesse setzen, dann stimmt die Flaeche auch headless.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	size = get_viewport_rect().size
	queue_redraw()

## Flaeche des Knopfes in Bildschirmkoordinaten. Skaliert mit der Breite, damit
## der Knopf auf jedem Hochformat gleich gross wirkt, und ist nach unten
## gedeckelt, damit er auf flachen Fenstern nicht die halbe Hoehe frisst.
static func rect_for(viewport_size: Vector2) -> Rect2:
	var unit := clampf(viewport_size.x / 1080.0, 0.25, 1.6)
	var button_size := JumpConfig.PAUSE_BUTTON_SIZE * unit
	var margin := JumpConfig.PAUSE_BUTTON_MARGIN * unit
	return Rect2(Vector2(viewport_size.x - margin - button_size.x, margin), button_size)

func _draw() -> void:
	var rect := rect_for(size)
	if rect.size.x <= 0.0:
		return
	var unit := rect.size.x / JumpConfig.PAUSE_BUTTON_SIZE.x
	draw_rect(rect, JumpConfig.PAUSE_BUTTON_PLATE_COLOR, true)
	# Haarlinien oben und unten statt eines Rahmens: dieselbe Formensprache wie
	# der Startbildschirm, damit beide Bildschirme als ein Produkt lesen.
	var line := maxf(1.0, 1.5 * unit)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, line)), JumpConfig.PAUSE_BUTTON_BORDER_COLOR, true)
	draw_rect(
		Rect2(rect.position + Vector2(0.0, rect.size.y - line), Vector2(rect.size.x, line)),
		JumpConfig.PAUSE_BUTTON_BORDER_COLOR,
		true
	)
	# Zwei Balken statt eines Schriftzeichens: keine Schriftart haengt davon ab,
	# ob das Pausensymbol vorhanden ist.
	var bar: Vector2 = JumpConfig.PAUSE_BUTTON_BAR_SIZE * unit
	var gap: float = JumpConfig.PAUSE_BUTTON_BAR_GAP * unit
	var block := Vector2(bar.x * 2.0 + gap, bar.y)
	var origin := rect.position + (rect.size - block) * 0.5
	draw_rect(Rect2(origin, bar), JumpConfig.PAUSE_BUTTON_BAR_COLOR, true)
	draw_rect(Rect2(origin + Vector2(bar.x + gap, 0.0), bar), JumpConfig.PAUSE_BUTTON_BAR_COLOR, true)
