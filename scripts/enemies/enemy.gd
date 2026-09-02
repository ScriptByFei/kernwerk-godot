class_name Enemy
extends LaneObject
## Gegner mit klarer Rollen-Silhouette: Grunt, Runner, Tank oder Boss.

signal enemy_killed(enemy: Enemy)
signal health_changed(enemy: Enemy, new_hp: int)

var max_hp := 50
var current_hp := 50
var is_boss := false
var enemy_type := EnemyArchetypeData.GRUNT
var score_reward := 10

var _hp_label: Label
var _wobble_tween: Tween
var _sprite
var animation_sheet_path := ""

const GRUNT_TEXTURE := preload("res://assets/sprites/grunt.png")
const RUNNER_TEXTURE := preload("res://assets/sprites/runner.png")
const TANK_TEXTURE := preload("res://assets/sprites/tank.png")
const BOSS_TEXTURE := preload("res://assets/sprites/boss.png")
const ANIMATION_DIRECTORY := "res://assets/sprites/generated/anim/"
const ANIMATION_FRAME_SIZE := 128

func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	_build_visual()

func configure(p_lane: int, hp: int, speed: float, p_is_boss: bool = false, p_enemy_type: String = EnemyArchetypeData.GRUNT) -> void:
	setup_lane(p_lane)
	max_hp = hp
	current_hp = hp
	move_speed = speed
	is_boss = p_is_boss
	enemy_type = EnemyArchetypeData.BOSS if is_boss else p_enemy_type
	score_reward = int(EnemyArchetypeData.get_definition(enemy_type)["score_reward"])

var configure_label := false  # Headless-Tests ohne Szene: Labels optional

func _build_visual() -> void:
	var old_sprite := get_node_or_null("Sprite")
	if old_sprite:
		old_sprite.queue_free()
	var scale_factor := 1.18
	var static_texture: Texture2D = GRUNT_TEXTURE
	var sheet_unit := "grunt"
	match enemy_type:
		EnemyArchetypeData.RUNNER:
			scale_factor = 0.92
			static_texture = RUNNER_TEXTURE
			sheet_unit = "runner"
		EnemyArchetypeData.TANK:
			scale_factor = 1.47
			static_texture = TANK_TEXTURE
			sheet_unit = "tank"
		EnemyArchetypeData.BOSS:
			scale_factor = 1.75
			static_texture = BOSS_TEXTURE
			sheet_unit = "boss"
	_sprite = _create_animated_sprite(sheet_unit, 4 if is_boss else 2, "pulse" if is_boss else "idle", 3.0 if is_boss else 4.0)
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture = static_texture
	_sprite.name = "Sprite"
	_sprite.scale = Vector2.ONE * scale_factor
	add_child(_sprite)
	build_label()

func _create_animated_sprite(unit: String, frame_count: int, animation_name: String, animation_speed: float) -> AnimatedSprite2D:
	var sheet_path := animation_sheet_path if not animation_sheet_path.is_empty() else ANIMATION_DIRECTORY + unit + "_sheet.png"
	if not FileAccess.file_exists(sheet_path):
		return null
	# Web-Export-sicher laden: FileAccess liest auch aus dem PCK (kein echtes
	# Dateisystem im Browser) — Image.load_from_file würde dort still fehlschlagen.
	var bytes := FileAccess.get_file_as_bytes(sheet_path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return null
	var sheet := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, animation_speed)
	frames.set_animation_loop(animation_name, true)
	for frame_index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(frame_index * ANIMATION_FRAME_SIZE, 0, ANIMATION_FRAME_SIZE, ANIMATION_FRAME_SIZE)
		frames.add_frame(animation_name, frame)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.play(animation_name)
	return sprite

func build_label() -> void:
	# HP-Label über dem Kopf — nil-safe (Headless-Tests ohne Rendering)
	_hp_label = Label.new()
	_hp_label.text = str(maxi(current_hp, 0))
	_hp_label.position = Vector2(-40, -128 if is_boss else -105)
	_hp_label.size = Vector2(80, 40)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hp_label.add_theme_font_size_override("font_size", 26)
	add_child(_hp_label)

var _dying := false  # Doppel-Kill-Schutz

func take_damage(dmg: int) -> void:
	if _dying:
		return
	current_hp -= dmg
	health_changed.emit(self, current_hp)
	if current_hp <= 0:
		_dying = true
		_die()
	else:
		if _hp_label:
			_hp_label.text = str(current_hp)
		_hit_feedback()

func _hit_feedback() -> void:
	# Sanftes Feedback: nur Wackeln — KEIN Weiß-Blitz über dem ganzen Sprite
	# (Timo-Playtest: Blitz wirkt zu hart, Wackeln reicht).
	# Wackeln UM DIE AKTUELLE POSITION — kein Sprung zu x=0 (das war der "nach links weg"-Bug)
	if _wobble_tween and _wobble_tween.is_valid():
		_wobble_tween.kill()
	var base_x := position.x
	_wobble_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_wobble_tween.tween_property(self, "position:x", base_x + 14.0, 0.05)
	_wobble_tween.tween_property(self, "position:x", base_x - 10.0, 0.07)
	_wobble_tween.tween_property(self, "position:x", base_x, 0.06)

func _die() -> void:
	# Sanftes Auflösen: schrumpfen + ausfaden, kein harter Pop
	if _hp_label: _hp_label.visible = false
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(0.1, 0.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(queue_free)
	enemy_killed.emit(self)

func _reach_y() -> float:
	# Gegner melden genau an der Spielerlinie, nicht erst unter dem Viewport.
	# LaneObject garantiert dabei das einmalige Signal und die Entfernung.
	return get_viewport_rect().size.y * GameConfig.ENEMY_REACH_Y_RATIO
