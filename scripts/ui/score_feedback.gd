class_name ScoreFeedback
extends Node2D

const POPUP_COLOR := Color(0.5, 1.0, 0.8, 0.95)
const POPUP_DISTANCE := 120.0
const POPUP_DURATION := 0.9
const BOSS_POPUP_DURATION := 1.3

func popup(text: String, at: Vector2) -> void:
	_show_popup(text, at, 34, POPUP_DURATION)

func popup_for(enemy: Enemy) -> void:
	_show_popup(
		"+%d" % enemy.score_reward,
		enemy.global_position + Vector2(0, -120),
		44 if enemy.is_boss else 34,
		BOSS_POPUP_DURATION if enemy.is_boss else POPUP_DURATION
	)

func _show_popup(text: String, at: Vector2, font_size: int, duration: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", POPUP_COLOR)
	label.position = at + Vector2(-90, -20)
	label.size = Vector2(180, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween := create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - POPUP_DISTANCE, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
