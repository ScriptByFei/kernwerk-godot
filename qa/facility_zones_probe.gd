extends SceneTree

## Facility-Probe: rendert alle fuenf Zonen im ECHTEN Zeichenweg bei Geraetegroesse.
## Belegt, dass die gemeinsame Facility-Struktur in jeder Zone traegt und dass die
## Zonen als Bereiche EINER Anlage lesen (nicht als ausgetauschte Kachel).
##
## Aufruf:
## xvfb-run -a -s "-screen 0 430x932x24" godot4 --rendering-driver opengl3 \
##   --resolution 430x932 --path . -s qa/facility_zones_probe.gd

const Game = preload("res://scripts/game/game.gd")
const JumpConfig = preload("res://scripts/jump/jump_config.gd")
const Background = preload("res://scripts/jump/shaft_background.gd")

const OUT := "/tmp/kernwerk-facility"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._phase = Game.Phase.PLAYING
	if game.start_menu != null:
		game.start_menu.visible = false
	game.jumper.set_physics_process(false)
	game.jumper.set_process(false)
	game.camera.set_physics_process(false)
	game.platform_director._clear_platforms()
	if game.hud != null:
		game.hud.visible = false
	game.camera.position = Vector2(540.0, 0.0)
	game.camera.force_update_scroll()
	await process_frame
	var reference: float = game._zone_height(game._get_visible_world_rect())
	var shots := [
		[0.0, "zone1-reaktor"], [0.3, "u1-2"], [1.0, "zone2-kuehlung"],
		[1.78, "u2-3"], [2.0, "zone3-hochspannung"], [2.78, "u3-4"],
		[3.0, "zone4-instabil"], [3.78, "u4-5"], [4.0, "zone5-kritisch"],
	]
	for entry in shots:
		var index: float = entry[0]
		var climbed: float = JumpConfig.zone_height_for_index(index)
		game.camera.position = Vector2(540.0, reference - climbed)
		game.camera.offset = Vector2.ZERO
		game.camera.force_update_scroll()
		game.jumper.position = Vector2(540.0, 880.0 - climbed)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT, entry[1]]
		var image := root.get_texture().get_image()
		if image.save_png(path) != OK:
			print("FEHLER beim Schreiben von ", path)
			quit(1)
			return
		print("%s | index=%.2f | schacht=%.2f kuehlung=%.2f z3=%.2f z4=%.2f z5=%.2f | facility=%.2f" % [
			entry[1], index,
			Background.opacity_for_zone(index),
			Background.cooling_opacity_for_zone(index),
			Background.zone3_opacity_for_zone(index),
			Background.zone4_opacity_for_zone(index),
			Background.zone5_opacity_for_zone(index),
			Background.facility_opacity_for_zone(index)])
	# Zusaetzlich je Zonengrenze ein Bild, das die Grenze in der BILDMITTE hat.
	# Ohne diese Ausrichtung liegt der Uebergangsabschnitt ausserhalb des
	# Ausschnitts und ein leeres Bild waere als "nicht gezeichnet" fehlzudeuten.
	for boundary in [1.0, 2.0, 3.0, 4.0]:
		var world_y: float = -JumpConfig.zone_height_for_index(boundary)
		var camera_pos: float = world_y - 1170.0
		game.camera.position = Vector2(540.0, camera_pos)
		game.camera.offset = Vector2.ZERO
		game.camera.force_update_scroll()
		game.jumper.position = Vector2(540.0, camera_pos + 1170.0 + 320.0)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var gate_path := "%s/gate-%d.png" % [OUT, int(boundary)]
		var gate_image := root.get_texture().get_image()
		if gate_image.save_png(gate_path) != OK:
			print("FEHLER beim Schreiben von ", gate_path)
			quit(1)
			return
		var bays := Background.facility_transition_bays(game._get_visible_world_rect())
		print("TOR %d | Zonenindex %.2f | Uebergaenge im Bild: %d" % [int(boundary), JumpConfig.zone_index_at(-camera_pos), bays.size()])
	print("FACILITY PROBE: %d Bilder in %s" % [shots.size() + 4, OUT])
	quit(0)
