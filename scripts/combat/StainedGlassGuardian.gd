class_name StainedGlassGuardian
extends EnemyBase
## Guardião do Vitral: 8 HP, escudo frontal (voltado para os flippers) reduz 80% do dano.
## Acertar uma runa lateral desativa o escudo por 5 segundos. Atira projéteis lentos.

@export var shield_radius: float = 44.0
@export var shield_down_seconds: float = 5.0
@export var fire_interval: float = 6.5

var shield: GuardianShield
var _shield_down_left := 0.0
var _fire_timer := 0.0
var projectile_scene: PackedScene
var shots := 0


func _setup() -> void:
	enemy_id = "guardian"
	shield = GuardianShield.new()
	shield.name = "Shield"
	shield.owner_guardian = self
	shield.radius = shield_radius
	add_child(shield)
	projectile_scene = load("res://scenes/effects/Projectile.tscn")
	_fire_timer = fire_interval * 0.6


func _on_alive_tick(delta: float) -> void:
	if _shield_down_left > 0.0:
		_shield_down_left -= delta
		if _shield_down_left <= 0.0:
			shield.set_active(true)
	if not GameManager.is_ball_in_play():
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire()


func _fire() -> void:
	var table := GameManager.table
	if table == null or projectile_scene == null:
		return
	shots += 1
	var p: Projectile = projectile_scene.instantiate()
	p.position = position + Vector2(0, shield_radius + 14.0)
	p.direction = Vector2(_rng.randf_range(-0.35, 0.35), 1.0).normalized()
	p.speed = 150.0
	table.get_dynamic_layer().add_child(p)
	sprite.modulate = Color(1.4, 1.2, 1.6)


## Chamado pela mesa quando qualquer runa é acertada.
func on_rune_hit() -> void:
	if not alive:
		return
	if shield.active:
		AudioManager.play_sfx("guardian_shield", 0.05, -2.0)
		SignalBus.hud_message.emit(Loc.t("guardian_shield_down"), 1.5)
	_shield_down_left = shield_down_seconds
	shield.set_active(false)


## Impacto no escudo: 80% de redução.
func on_shield_hit(ball: Ball, impact_speed: float, hit_pos: Vector2) -> void:
	if not alive:
		return
	var result := Combat.damage_for_impact(impact_speed, ball.consecrated, ScoreManager.combo_damage_bonus())
	var reduced := int(floor(result.damage * 0.2))
	if result.critical and reduced < 1:
		reduced = 1
	ScoreManager.register_hit("guardian_shield", 100, hit_pos)
	AudioManager.play_sfx("guardian_shield", 0.1, -4.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.4)
	if reduced > 0:
		health.apply_damage(reduced, hit_pos, false)


func _on_death_extra() -> void:
	shield.set_active(false)
	shield.set_deferred("visible", false)


func _on_revived() -> void:
	_shield_down_left = 0.0
	shield.set_deferred("visible", true)
	shield.set_active(true)
	_fire_timer = fire_interval * 0.6


class GuardianShield:
	extends StaticBody2D
	## Arco de vitral abaixo do Guardião (lado dos flippers).
	var owner_guardian: StainedGlassGuardian
	var radius := 44.0
	var active := true
	var _shapes: Array[CollisionShape2D] = []
	var _sprite: Sprite2D

	func _ready() -> void:
		collision_layer = 1 << 4
		collision_mask = 0
		physics_material_override = TableGeometry.metal_material()
		var pts := TableGeometry.arc_points(Vector2.ZERO, radius, radius, 15.0, 165.0, 10)
		for i in range(pts.size() - 1):
			var cs := CollisionShape2D.new()
			var seg := SegmentShape2D.new()
			seg.a = pts[i]
			seg.b = pts[i + 1]
			cs.shape = seg
			add_child(cs)
			_shapes.append(cs)
		_sprite = Sprite2D.new()
		if ResourceLoader.exists("res://assets/art/guardian_shield.png"):
			_sprite.texture = load("res://assets/art/guardian_shield.png")
			_sprite.position = Vector2(0, radius * 0.55)
			_sprite.scale = Vector2(radius * 2.2 / 96.0, radius * 1.1 / 48.0)
		else:
			var line := Line2D.new()
			line.points = pts
			line.width = 6.0
			line.default_color = Color(0.78, 0.49, 1.0)
			_sprite.add_child(line)
		add_child(_sprite)

	func apply_skin(texture: Texture2D) -> void:
		if texture == null:
			return
		for c in _sprite.get_children():
			c.queue_free()
		TableGeometry.fit_sprite(_sprite, texture, radius * 2.0)
		_sprite.position = Vector2(0, radius * 0.85)

	func set_active(value: bool) -> void:
		active = value
		for cs in _shapes:
			cs.set_deferred("disabled", not value)
		_sprite.modulate = Color.WHITE if value else Color(1, 1, 1, 0.2)

	func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
		if owner_guardian != null:
			owner_guardian.on_shield_hit(ball, impact_speed, hit_pos)
