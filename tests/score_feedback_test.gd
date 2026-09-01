extends SceneTree

const ScoreFeedbackScript = preload("res://scripts/ui/score_feedback.gd")

var fails := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ " + msg)
	else:
		fails += 1
		print("  ✗ " + msg)

func _init() -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var feedback := ScoreFeedbackScript.new()
	world.add_child(feedback)

	feedback.popup("+10", Vector2(200, 300))
	await process_frame
	_check(_popup_labels(feedback).any(func(label): return label.text == "+10"), "popup erzeugt ein +10-Label")

	var grunt := Enemy.new()
	grunt.configure(0, 50, 0.0, false, EnemyArchetypeData.GRUNT)
	grunt.global_position = Vector2(300, 400)
	world.add_child(grunt)
	feedback.popup_for(grunt)
	await process_frame
	_check(_popup_labels(feedback).any(func(label): return label.text == "+10"), "Grunt-Popup nutzt Score-Reward 10")

	var boss := Enemy.new()
	boss.configure(0, 600, 90.0, true, EnemyArchetypeData.BOSS)
	world.add_child(boss)
	feedback.popup_for(boss)
	await process_frame
	_check(_popup_labels(feedback).any(func(label): return label.text == "+100"), "Boss-Popup nutzt bestehenden Score-Reward 100")

	await create_timer(1.5).timeout
	_check(_popup_labels(feedback).is_empty(), "Popup-Labels werden nach den Tweens entfernt")

	if fails == 0:
		print("SCORE FEEDBACK TESTS: ALLE OK")
	else:
		print("SCORE FEEDBACK TESTS: %d FEHLER" % fails)
	world.queue_free()
	await process_frame
	quit(1 if fails > 0 else 0)

func _popup_labels(feedback: Node2D) -> Array[Label]:
	var labels: Array[Label] = []
	for child in feedback.get_children():
		if child is Label:
			labels.append(child)
	return labels
