class_name RuneTurret
extends EnemyBase
## Torre de runas: alvo fixo que telegrafa e dispara um projétil lento na direção dos flippers.

@export var fire_interval: float = 5.5
@export var telegraph: float = 0.5

var _timer := 0.0
var _tele_left := 0.0
var projectile_scene: PackedScene
var shots := 0


func _setup() -> void:
	enemy_id = "turret_%d" % get_instance_id()
	projectile_scene = load("res://scenes/effects/Projectile.tscn")
	_timer = fire_interval * 0.7


func _on_alive_tick(delta: float) -> void:
	if not GameManager.is_ball_in_play():
		return
	if _tele_left > 0.0:
		_tele_left -= delta
		sprite.modulate = Color(1.3, 0.9, 1.5) if int(_tele_left * 10.0) % 2 == 0 else Color.WHITE
		if _tele_left <= 0.0:
			sprite.modulate = Color.WHITE
			_fire()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = fire_interval
		_tele_left = telegraph
		if animator != null:
			animator.play("attack", telegraph + 0.4)


func _fire() -> void:
	var table := GameManager.table
	if table == null or projectile_scene == null:
		return
	shots += 1
	var p: Projectile = projectile_scene.instantiate()
	p.position = position + Vector2(0, body_radius + 10.0)
	var target := Vector2(380.0, 1000.0)
	p.direction = (target - position).normalized().rotated(_rng.randf_range(-0.15, 0.15))
	p.speed = 140.0
	table.get_dynamic_layer().call_deferred("add_child", p)
	AudioManager.play_sfx("projectile_break", 0.1, -8.0)
