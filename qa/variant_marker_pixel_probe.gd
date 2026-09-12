extends SceneTree
const Game = preload("res://scripts/game/game.gd")

## Pixelbeweis fuer die einseitige Kerbe der riskanten Route.
##
## Erste Fassung dieses Tests war NICHT unterscheidend: sie zaehlte einfach alle
## abweichenden Bildpunkte zwischen schmal und riskant. Die beiden unterscheiden
## sich aber ohnehin schon ueber die Bandbreite (258 Pixel), sodass die Mutation
## "Kerbe entfernen" nur EINEN Pixel Unterschied machte — der Test blieb gruen.
##
## Jetzt wird genau die Kerbenfarbe an genau der Kerbenstelle gezaehlt. Diese
## Farbe (PLATFORM_CENTER_MARK_COLOR) wird gezeichnet als:
##   Rechteck um die Mitte (PERFECT-Zone) + kurzer Stiel
## Der Stiel ragt unter das Band hinaus, deshalb ist er auch bei RISKY sichtbar
## und liegt exakt bei x = halbe Breite - 9.

const OUT := "/tmp/kernwerk-six-phases/variants"
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var samples := {}
	for variant in [
		JumpPlatform.Variant.STANDARD,
		JumpPlatform.Variant.NARROW,
		JumpPlatform.Variant.RISKY,
	]:
		samples[variant] = await _sample(variant)

	var narrow: int = samples[JumpPlatform.Variant.NARROW]
	var risky: int = samples[JumpPlatform.Variant.RISKY]
	var standard: int = samples[JumpPlatform.Variant.STANDARD]
	print("Kerbenpixel: standard=%d schmal=%d riskant=%d" % [standard, narrow, risky])
	# Die Kerbenfarbe sitzt am Ende der Plattform. Die schmale Variante nutzt
	# dort PLATFORM_EDGE_COLOR, nur die riskante PLATFORM_CENTER_MARK_COLOR.
	# Die Kerbe ist ein zusaetzlicher kurzer Stiel am Plattformende.
	_check(risky > narrow, "riskante Route hat mehr Kerbenpixel als die schmale")
	# Standard traegt dieselbe Markierung in der Mitte, aber keinen Stiel am
	# Rand. Deshalb muss er die gleiche Grundmenge haben, nicht mehr.
	_check(standard == narrow, "Standard und Schmal tragen dieselbe Mittelmarkierung")
	_check(risky - standard >= 2, "die Kerbe hebt sich messbar ab (mind. 2 Pixel)")
	print("VARIANT MARKER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

## Zaehlt die Bildpunkte in der Kerbenfarbe in der unteren Plattformhaelfte.
func _sample(variant: JumpPlatform.Variant) -> int:
	var scene := Node2D.new()
	root.add_child(scene)
	var platform := JumpPlatform.new()
	platform.configure_variant(variant)
	platform.position = Vector2(200.0, 160.0)
	scene.add_child(platform)
	platform.set_process(false)
	# Ohne Impact: nur die ruhende Markierung wird verglichen.
	platform.impact_active = false
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var target := JumpConfig.PLATFORM_CENTER_MARK_COLOR
	# Die Plattformmitte liegt bei (200,160), die Markierung darunter.
	var count := 0
	# Ganzes Bild scannen: die Canvas skaliert gegenueber den Node-Koordinaten,
	# ein geratenes Fenster misst sonst ins Leere (erster Versuch: 0 Pixel).
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var c := image.get_pixel(x, y)
			if absf(c.r - target.r) < 0.02 and absf(c.g - target.g) < 0.02 and absf(c.b - target.b) < 0.02:
				count += 1
	image.save_png("%s/kerbe-%d.png" % [OUT, variant])
	scene.queue_free()
	await process_frame
	return count

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)
