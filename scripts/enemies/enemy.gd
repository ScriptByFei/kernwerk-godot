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

const DETAIL_LIGHT := Color(1.0, 0.92, 0.9, 0.72)
const TANK_ARMOR_COLOR := Color(0.92, 0.42, 0.30, 0.9)
const BOSS_CORE_COLOR := Color(0.82, 0.56, 0.92, 0.78)

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
	var definition := EnemyArchetypeData.get_definition(enemy_type)
	var body := Polygon2D.new()
	body.color = definition["color"]
	match enemy_type:
		EnemyArchetypeData.RUNNER:
			# Raute mit seitlichen Flügeln = schnell und leicht.
			body.polygon = PackedVector2Array([Vector2(0, -67), Vector2(48, 0), Vector2(0, 67), Vector2(-48, 0)])
		EnemyArchetypeData.TANK:
			# Breiter Block = langsam und widerstandsfähig.
			body.polygon = PackedVector2Array([Vector2(-76, -51), Vector2(76, -51), Vector2(76, 51), Vector2(-76, 51)])
		EnemyArchetypeData.BOSS:
			body.polygon = PackedVector2Array([Vector2(-55, -85), Vector2(55, -85), Vector2(85, -55), Vector2(85, 55), Vector2(55, 85), Vector2(-55, 85), Vector2(-85, 55), Vector2(-85, -55)])
		_:
			# Die abgeschnittene Ecke macht den Standardgegner weniger generisch.
			body.polygon = PackedVector2Array([Vector2(-38, -55), Vector2(55, -55), Vector2(55, 55), Vector2(-55, 55), Vector2(-55, -38)])
	add_child(body)
	match enemy_type:
		EnemyArchetypeData.GRUNT:
			_add_detail(PackedVector2Array([Vector2(14, -18), Vector2(24, -18), Vector2(24, -8), Vector2(14, -8)]), DETAIL_LIGHT)
		EnemyArchetypeData.RUNNER:
			_add_detail(PackedVector2Array([Vector2(-43, -18), Vector2(-67, 0), Vector2(-43, 18)]), DETAIL_LIGHT)
			_add_detail(PackedVector2Array([Vector2(43, -18), Vector2(67, 0), Vector2(43, 18)]), DETAIL_LIGHT)
		EnemyArchetypeData.TANK:
			_add_detail(PackedVector2Array([Vector2(-58, -9), Vector2(58, -9), Vector2(58, 9), Vector2(-58, 9)]), TANK_ARMOR_COLOR)
			for corner in [Vector2(-61, -36), Vector2(61, -36), Vector2(-61, 36), Vector2(61, 36)]:
				_add_detail(PackedVector2Array([corner + Vector2(-6, -6), corner + Vector2(6, -6), corner + Vector2(6, 6), corner + Vector2(-6, 6)]), DETAIL_LIGHT)
		EnemyArchetypeData.BOSS:
			_add_detail(PackedVector2Array([Vector2(-19, -30), Vector2(19, -30), Vector2(30, -19), Vector2(30, 19), Vector2(19, 30), Vector2(-19, 30), Vector2(-30, 19), Vector2(-30, -19)]), BOSS_CORE_COLOR)
	build_label()

func _add_detail(points: PackedVector2Array, detail_color: Color) -> void:
	var detail := Polygon2D.new()
	detail.polygon = points
	detail.color = detail_color
	add_child(detail)

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
		_flash_rect.polygon = PackedVector2Array([Vector2(-57, -57), Vector2(57, -57), Vector2(57, 57), Vector2(-57, 57)])
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
