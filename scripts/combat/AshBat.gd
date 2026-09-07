class_name AshBat
extends AnimatableBody2D
## Morcego de Cinzas: 2 HP, move-se entre três pontos predeterminados (sem perseguir a bola).
## Solta fragmento de mana ao morrer.

signal enemy_died(enemy: Node, points: int)

@export var data: EnemyData
@export var waypoints: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(120, -40), Vector2(240, 0)])
@export var move_speed: float = 130.0
@export var body_radius: float = 16.0
@export var enemy_id: String = "bat"
@export var respawns: bool = true

var health: HealthComponent
var alive := true
var sprite: Sprite2D
var _shape: CollisionShape2D
var _wp_index := 1
var _flash := 0.0
var _respawn_left := 0.0
var kills := 0
var _origin := Vector2.ZERO
var mana_fragment_scene: PackedScene


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1 << 4
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	_origin = position
	if data == null:
		data = EnemyData.new()
		data.max_hp = 2
		data.points_on_death = 1500
		data.mana_on_death = 0
		data.respawn_seconds = 15.0
	health = HealthComponent.new()
	health.max_hp = data.max_hp
	health.points_on_death = data.points_on_death
	health.invulnerability_ms = data.invulnerability_ms
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	_shape.shape = circle
	add_child(_shape)
	sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/ash_bat.png"):
		sprite.texture = load("res://assets/art/ash_bat.png")
	add_child(sprite)
	mana_fragment_scene = load("res://scenes/effects/ManaFragment.tscn")


func _physics_process(delta: float) -> void:
	if alive:
		if waypoints.size() >= 2 and GameManager.is_in_game():
			var target := _origin + waypoints[_wp_index]
			var to_target := target - position
			var step := move_speed * delta
			if to_target.length() <= step:
				position = target
				_wp_index = (_wp_index + 1) % waypoints.size()
			else:
				position += to_target.normalized() * step
			sprite.flip_h = to_target.x < 0.0
	elif respawns and _respawn_left > 0.0 and GameManager.is_in_game():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			revive()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		sprite.modulate = Color.WHITE.lerp(Color(2.0, 1.2, 1.2), _flash)
	sprite.position.y = sin(Time.get_ticks_msec() * 0.008) * 3.0


func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	if not alive:
		return
	var result := Combat.damage_for_impact(impact_speed, ball.consecrated, ScoreManager.combo_damage_bonus())
	var applied: int = health.apply_damage(result.damage, hit_pos, result.critical)
	ScoreManager.register_hit(enemy_id, data.points_on_hit, hit_pos)
	if applied > 0:
		var table := GameManager.table
		if table != null:
			table.add_mana(data.mana_on_hit)
			if ball.consecrated:
				table.magic.shockwave(hit_pos, self)
		AudioManager.play_sfx("enemy_crit" if result.critical else "enemy_hit", 0.08, 0.0, 30)
		SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.6)


func take_area_damage(amount: int, origin: Vector2) -> void:
	if alive:
		health.apply_damage(amount, origin, false)


func _on_damaged(amount: int, hit_position: Vector2, critical: bool) -> void:
	_flash = 1.0
	SignalBus.enemy_damaged.emit(self, amount, hit_position, critical)


func _on_died(points: int) -> void:
	alive = false
	kills += 1
	ScoreManager.add_points_raw(points)
	AudioManager.play_sfx("enemy_death", 0.08, 0.0, 30)
	SignalBus.impact.emit(global_position, 0.7)
	_shape.set_deferred("disabled", true)
	sprite.visible = false
	# Fragmento de mana cai da posição do morcego.
	var table := GameManager.table
	if table != null and mana_fragment_scene != null:
		var frag := mana_fragment_scene.instantiate()
		frag.position = position
		table.get_dynamic_layer().call_deferred("add_child", frag)
	enemy_died.emit(self, points)
	SignalBus.enemy_died.emit(self, points, global_position)
	if respawns:
		_respawn_left = data.respawn_seconds


func revive() -> void:
	alive = true
	health.revive()
	_shape.set_deferred("disabled", false)
	sprite.visible = true
	sprite.modulate = Color.WHITE


func force_reset() -> void:
	_respawn_left = 0.0
	position = _origin
	_wp_index = 1 if waypoints.size() > 1 else 0
	revive()
