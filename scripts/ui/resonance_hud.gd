class_name ResonanceHud
extends Control

## Minimalistisches Resonanz-HUD in Bildschirmkoordinaten.
##
## Liegt bewusst in einer eigenen CanvasLayer: im Weltraum gezeichnete HUD-Texte
## werden von vorbeiziehenden Plattformen ueberdeckt (im QA-Bild schnitt eine
## Plattform den SCORE-Text an). Als Overlay bleibt die Anzeige immer lesbar.
##
## Zeigt drei Resonanzsegmente. Da das Spiel automatisch beim Landen abspringt,
## gibt es keinen sichtbaren Zustand mit 3/3 — der letzte Treffer entlaedt sofort.
## OVERLOAD wird deshalb VOR dem ausloesenden Treffer angekuendigt und waehrend
## des ueberladenen Flugs weiter benannt.

var resonance: ResonanceSystem
var score := 0
## Restlaufzeit der OVERLOAD-Anzeige, vom Spiel gesetzt.
var overload_display := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Das HUD darf keine Eingaben abfangen: die Steuerung laeuft ueber die Szene.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if resonance == null:
		return
	draw_string(
		ThemeDB.fallback_font,
		JumpConfig.RESONANCE_HUD_ORIGIN,
		"SCORE %06d" % score,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		42,
		Color(0.72, 1.0, 0.92)
	)
	_draw_charges()


func _draw_charges() -> void:
	var charges := resonance.charges
	var max_charges := resonance.max_charges()
	var segment: Vector2 = JumpConfig.RESONANCE_HUD_SEGMENT_SIZE
	var gap: float = JumpConfig.RESONANCE_HUD_SEGMENT_GAP
	var base: Vector2 = JumpConfig.RESONANCE_HUD_ORIGIN + Vector2(0.0, JumpConfig.RESONANCE_HUD_ROW_OFFSET)
	# Die naechste volle Landung entlaedt OVERLOAD. Der Hinweis muss also VOR
	# dem ausloesenden Treffer erscheinen, sonst sieht ihn niemand.
	var overload_ready := charges >= max_charges - 1
	for index in max_charges:
		var rect := Rect2(base + Vector2(index * (segment.x + gap), 0.0), segment)
		if overload_display > 0.0:
			# Overload ist verbraucht und wirkt gerade: alle Slots leuchten.
			draw_rect(rect, JumpConfig.RESONANCE_OVERLOAD_COLOR)
		elif index < charges:
			# Das letzte gefuellte Segment ist die Ladung, die OVERLOAD scharf
			# macht: sie traegt schon jetzt die Overload-Farbe.
			var last_filled := index == charges - 1
			var color := JumpConfig.RESONANCE_OVERLOAD_COLOR if (last_filled and overload_ready) else JumpConfig.RESONANCE_HUD_CHARGE_COLOR
			draw_rect(rect, color)
		draw_rect(rect, JumpConfig.RESONANCE_HUD_DIM_COLOR, false, JumpConfig.RESONANCE_HUD_OUTLINE_WIDTH)
	if overload_ready or overload_display > 0.0:
		draw_string(
			ThemeDB.fallback_font,
			base + Vector2(JumpConfig.resonance_hud_width() + 18.0, segment.y - 3.0),
			JumpConfig.RESONANCE_OVERLOAD_LABEL,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			22,
			JumpConfig.RESONANCE_OVERLOAD_COLOR
		)
