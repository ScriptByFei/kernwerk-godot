extends SceneTree
const Game = preload("res://scripts/game/game.gd")
var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + description)
func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var menu: StartMenu = game._current_menu
	_check(menu.bg.modulate.a <= 0.35, "live world exposed")
	_check(menu.cta_label.text == "REAKTOR STARTEN", "exact CTA")
	_check(menu.title_label.text == "KERNWERK", "primary title")
	_check(menu.get_parent() is CanvasLayer, "screen-fixed layer")
	var positions := [menu.title_label.position, menu.cta_panel.position]
	var idle := menu._idle_tween
	idle.pause()
	for step in [0.4, 0.6, 1.2, 1.2]:
		idle.custom_step(step)
		_check(menu.cta_panel.scale == Vector2.ONE and menu.title_label.scale == Vector2.ONE, "no UI scale pulse")
		_check(positions == [menu.title_label.position, menu.cta_panel.position], "idle labels remain planted")
		_check(menu.bg.self_modulate.r >= 0.74 and menu.bg.self_modulate.r <= 0.781, "bounded cheap chamber light")
	for resolution in [Vector2i(320,568), Vector2i(390,844), Vector2i(430,932), Vector2i(1280,720), Vector2i(844,390)]:
		root.size = resolution
		await process_frame
		await process_frame
		var scale_factor := root.get_stretch_transform().x.length()
		var safe := Rect2(Vector2.ZERO, menu.size).grow(-8)
		for node: Control in [menu.title_label,menu.subtitle_label,menu.cta_panel]:
			_check(safe.encloses(node.get_rect()), "bounds %s %s" % [resolution,node.name])
			_check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "input remains unhandled")
		for label: Label in [menu.title_label,menu.subtitle_label,menu.cta_label]:
			var minimum := label.get_minimum_size()
			_check(label.size.x >= minimum.x and label.size.y >= minimum.y, "unclipped text %s %s" % [resolution,label.text])
		_check(menu.cta_panel.size.y * scale_factor >= 43.9, "44px CTA presentation")
		_check(menu.cta_label.get_theme_font_size("font_size") * scale_factor >= 11.99, "readable landscape CTA")
		_check(menu.title_label.get_theme_font_size("font_size") * scale_factor >= 21.99, "readable landscape title")
		_check(menu.subtitle_label.get_rect().end.y < menu.cta_panel.position.y, "separated text and CTA")
		print("RESPONSIVE ", resolution, " viewport=",menu.size," scale=",scale_factor," CTA=",menu.cta_panel.size*scale_factor)
	var camera_before: Vector2 = game.camera.position + game.camera.offset
	var ui_before := menu.cta_panel.position
	game.camera.position.y -= 60
	game.camera.force_update_scroll()
	_check(menu.cta_panel.position == ui_before, "camera cannot move screen-fixed menu")
	game.camera.position.y += 60
	game.camera.force_update_scroll()
	game._start_game()
	game._start_tween.pause()
	_check(menu._idle_tween == null and not idle.is_valid(), "idle effect ceases immediately at tap")
	_check(menu.cta_panel.scale == Vector2.ONE and menu.cta_panel.self_modulate.r > 1.0, "instant ignition without punch")
	_check(game.camera.position + game.camera.offset == camera_before, "no new camera handover")
	game._start_tween.custom_step(JumpConfig.START_BOUNCE_AT + 0.01)
	game.jumper.set_physics_process(false)
	game.camera.set_physics_process(false)
	_check(game._phase == game.Phase.PLAYING, "approved handoff")
	_check(game.jumper.modulate == Color.WHITE, "reactor tint restored in PLAYING")
	await process_frame
	_check(not is_instance_valid(menu), "overlay effects removed in PLAYING")
	game._restart()
	await process_frame
	_check(game._current_menu._idle_tween != null, "standby light restored after restart")
	_check(game.jumper.modulate == Color(0.92,0.94,0.96), "standby reactor restored")
	game.queue_free()
	await process_frame
	print("STANDBY POLISH: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
