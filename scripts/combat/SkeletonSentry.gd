class_name SkeletonSentry
extends EnemyBase
## Esqueleto-sentinela: 3 HP, quase estático. Ataque telegráfico: estende uma lança que altera
## uma rota por 1 segundo. Ensina que a bola causa dano.

@export var lance_direction: Vector2 = Vector2(1, -0.4)
@export var lance_length: float = 75.0
@export var attack_interval_min: float = 6.0
@export var attack_interval_max: float = 9.0

const TELEGRAPH := 0.45  # antecipação mínima de 400 ms
const LANCE_TIME := 1.0

var _lance_body: StaticBody2D
var _lance_shape: CollisionShape2D
var _lance_line: Line2D
var _attack_timer := 0.0
var _phase := 0  # 0 idle, 1 telegraph, 2 lance out
var _phase_left := 0.0
var attacks := 0


func _setup() -> void:
	enemy_id = "skeleton_%d" % get_instance_id()
	_lance_body = StaticBody2D.new()
	_lance_body.name = "Lance"
	_lance_body.collision_layer = 1
	_lance_body.collision_mask = 0
	_lance_body.physics_material_override = TableGeometry.metal_material()
	_lance_shape = CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = lance_direction.normalized() * body_radius
	seg.b = lance_direction.normalized() * (body_radius + lance_length)
	_lance_shape.shape = seg
	_lance_shape.disabled = true
	_lance_body.add_child(_lance_shape)
	_lance_line = Line2D.new()
	_lance_line.points = PackedVector2Array([seg.a, seg.b])
	_lance_line.width = 5.0
	_lance_line.default_color = Color(0.91, 0.87, 0.78)
	_lance_line.visible = false
	_lance_body.add_child(_lance_line)
	add_child(_lance_body)
	_attack_timer = _rng.randf_range(attack_interval_min, attack_interval_max)


func _on_alive_tick(delta: float) -> void:
	if not GameManager.is_ball_in_play():
		return
	match _phase:
		0:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_phase = 1
				_phase_left = TELEGRAPH
				sprite.modulate = Color(1.0, 0.5, 0.5)
				AudioManager.play_sfx("skeleton_attack", 0.1, -6.0, 100)
		1:
			_phase_left -= delta
			sprite.modulate = Color(1.0, 0.5, 0.5) if int(_phase_left * 12.0) % 2 == 0 else Color.WHITE
			if _phase_left <= 0.0:
				_phase = 2
				_phase_left = LANCE_TIME
				attacks += 1
				sprite.modulate = Color.WHITE
				_lance_shape.set_deferred("disabled", false)
				_lance_line.visible = true
		2:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_retract()


func _retract() -> void:
	_phase = 0
	_phase_left = 0.0
	_lance_shape.set_deferred("disabled", true)
	_lance_line.visible = false
	_attack_timer = _rng.randf_range(attack_interval_min, attack_interval_max)


func _on_death_extra() -> void:
	_retract()


func _on_revived() -> void:
	_retract()


func is_lance_out() -> bool:
	return _phase == 2
