extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Zeichenlast des Reaktorschacht-Hintergrunds.
##
## Drei Vorgaenger-Messungen waren wertlos und sind hier festgehalten, damit sie
## nicht wiederholt werden:
##   1. "Bildzeit mit/ohne Hintergrund": 15.9 ms Mehraufwand. Artefakt der
##      Frame-Begrenzung im Software-Renderer. Eine Gegenprobe mit 2000
##      zusaetzlichen Rechtecken kostete WENIGER als "nichts" (-2.4 ms).
##   2. CPU-Zeit des Zeichenaufrufs: ebenfalls blind, 10-fache Details kosteten
##      weniger als der einfache Durchlauf.
##   3. Hintergrund abschalten ueber einen hoeheren Zonenstand: verfaelscht, weil
##      eine andere Kameraposition auch andere Plattformen zeigt. Der Vergleich
##      misst dann den Spielinhalt mit, nicht den Hintergrund.
## Wanduhr- und CPU-Messung sind hier untauglich, weil die Zeit von der
## Anzeige-Aktualisierung dominiert wird.
##
## Verlaesslich ist Godots eigener Zaehler
## (Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME). Gemessen wird er in ZWEI
## sauberen Schritten auf DEMSELBEN sichtbaren Ausschnitt:
##   a) das Spiel in der Zone (Vordergrund + Hintergrund)
##   b) nur der Hintergrund (dieselbe Zeichenroutine, derselbe Ausschnitt)
## Der Vordergrund ergibt sich als Differenz — beide Zahlen sind gemessen, keine
## ist geschaetzt.

## Obergrenze der gezeichneten Primitive je Bild durch den Hintergrund.
const MAX_PRIMITIVES := 700

## Kamerahoehe der Messung: mitten im Reaktorschacht.
const CAMERA_HEIGHT := 1200.0

const FRAMES := 20

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var total := await _measure_game()
	var background := await _measure_background()
	var foreground := total - background
	print("Spiel gesamt (Vordergrund + Hintergrund): %.0f Primitive" % total)
	print("Nur Hintergrund:                          %.0f Primitive" % background)
	print("Vordergrund (Spiel minus Hintergrund):    %.0f Primitive" % foreground)
	var share := background / total * 100.0 if total > 0.0 else 0.0
	print("Anteil des Hintergrunds am Bild:          %.1f %%" % share)
	var sensitive := background > 0.0
	print("Zaehler reagiert auf den Hintergrund: %s" % ("JA" if sensitive else "NEIN - untauglich"))
	print("(ohne Hintergrund bleibt der Vordergrund: %s)" % ("JA" if foreground > 0.0 else "NEIN"))
	if sensitive:
		print("Auslastung der Obergrenze %d: %.1f %%" % [MAX_PRIMITIVES, background / float(MAX_PRIMITIVES) * 100.0])
	quit(0 if (sensitive and foreground > 0.0 and background <= MAX_PRIMITIVES) else 1)

## a) Das echte Spiel in der Zone: Vordergrund und Hintergrund zusammen.
func _measure_game() -> float:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game._phase = Game.Phase.PLAYING
	if is_instance_valid(game.start_menu):
		game.start_menu.visible = false
	game.set_process(true)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	game.camera.position.y = -CAMERA_HEIGHT + JumpConfig.CAMERA_LEAD
	game.camera.force_update_scroll()
	return await _sample(game)

## b) Nur der Hintergrund, auf demselben sichtbaren Ausschnitt.
func _measure_background() -> float:
	var canvas := BackgroundOnly.new()
	root.add_child(canvas)
	canvas.rect = Rect2(0.0, -CAMERA_HEIGHT, 1080.0, 2342.0)
	canvas.zone = JumpConfig.zone_index_at(CAMERA_HEIGHT)
	return await _sample(canvas)

## Median der gezeichneten Primitive ueber mehrere Bilder, nach einer
## Aufwaermphase. Median statt Mittelwert: einzelne Ausreisser wuerden den
## Mittelwert verzerren.
func _sample(node: Node) -> float:
	for warmup in range(8):
		node.queue_redraw()
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	for frame in range(FRAMES):
		node.queue_redraw()
		await RenderingServer.frame_post_draw
		samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var count := samples.size()
	node.queue_free()
	await process_frame
	samples.sort()
	return samples[count / 2]

## Zeichnet ausschliesslich den Hintergrund.
class BackgroundOnly extends Node2D:
	var rect := Rect2()
	var zone := 0.0
	var time := 1.0
	func _draw() -> void:
		ShaftBackground.draw(self, rect, zone, time)
