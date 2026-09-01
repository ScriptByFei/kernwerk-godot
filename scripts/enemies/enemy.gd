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

var _flash_rect: Polygon2D
var _hp_label: Label
var _wobble_tween: Tween
var _sprite: Sprite2D

const GRUNT_TEXTURE := preload("res://assets/sprites/grunt.png")
const RUNNER_TEXTURE := preload("res://assets/sprites/runner.png")
const TANK_TEXTURE := preload("res://assets/sprites/tank.png")
const BOSS_TEXTURE := preload("res://assets/sprites/boss.png")

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
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	match enemy_type:
		EnemyArchetypeData.RUNNER:
			_sprite.texture = RUNNER_TEXTURE
			_sprite.scale = Vector2.ONE * 0.92
		EnemyArchetypeData.TANK:
			_sprite.texture = TANK_TEXTURE
			_sprite.scale = Vector2.ONE * 1.47
		EnemyArchetypeData.BOSS:
			_sprite.texture = BOSS_TEXTURE
			_sprite.scale = Vector2.ONE * 1.75
		_:
			_sprite.texture = GRUNT_TEXTURE
			_sprite.scale = Vector2.ONE * 1.18
	add_child(_sprite)
	build_label()

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
	# Sanftes Feedback: kurzer Weiß-Blitz + leichtes Wackeln — kein "MISS"/kein hartes Label
	if _flash_rect == null:
		_flash_rect = Polygon2D.new()
		_flash_rect.color = Color(1, 1, 1, 0.0)
		var half_size := _sprite.texture.get_size() * _sprite.scale * 0.5
		_flash_rect.polygon = PackedVector2Array([Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)])
		add_child(_flash_rect)
	# Blitz: kurz aufblitzen und ausfaden
	_flash_rect.color = Color(1, 1, 1, 0.55)
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.0, 0.15)
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
