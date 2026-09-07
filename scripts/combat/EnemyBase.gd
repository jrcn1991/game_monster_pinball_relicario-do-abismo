class_name EnemyBase
extends StaticBody2D
## Base para inimigos estáticos. Recebe impactos da bola via on_ball_hit, tem HealthComponent,
## morre (some e desativa colisão) e pode renascer via revive().

signal enemy_died(enemy: EnemyBase, points: int)
signal enemy_damaged(enemy: EnemyBase, amount: int, hit_position: Vector2)

@export var data: EnemyData
@export var enemy_id: String = "enemy"
@export var body_radius: float = 18.0
@export var texture_path: String = ""
@export var respawns: bool = true

var health: HealthComponent
var alive := true
var sprite: Sprite2D
var _flash := 0.0
var _shape: CollisionShape2D
var kills := 0
var _respawn_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	if data == null:
		data = EnemyData.new()
	health = HealthComponent.new()
	health.name = "Health"
	health.max_hp = data.max_hp
	health.points_on_death = data.points_on_death
	health.invulnerability_ms = data.invulnerability_ms
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	_shape.shape = circle
	add_child(_shape)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	else:
		var poly := Polygon2D.new()
		poly.polygon = TableGeometry.circle_points(Vector2.ZERO, body_radius, 16)
		poly.color = Color(0.9, 0.22, 0.27)
		sprite.add_child(poly)
	add_child(sprite)
	_rng.seed = GameManager.run_seed + hash(enemy_id)
	_setup()


## Ganchos para subclasses.
func _setup() -> void:
	pass


func _on_alive_tick(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if alive:
		_on_alive_tick(delta)
	elif respawns and _respawn_left > 0.0 and GameManager.is_in_game():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			revive()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		sprite.modulate = Color.WHITE.lerp(Color(2.0, 1.2, 1.2), _flash)


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
		AudioManager.play_sfx("enemy_crit" if result.critical else "enemy_hit", 0.08, 4.0 if result.critical else 2.0, 30)
		if result.critical:
			AudioManager.play_sfx("boss_hit", 0.05, -6.0, 60)
		SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * (1.0 if result.critical else 0.6))
		if result.critical:
			SignalBus.request_flash.emit(Color(0.78, 0.49, 1.0), 0.15)


## Dano em área (onda da Bola Consagrada): sem empurrar, respeita invulnerabilidade.
func take_area_damage(amount: int, origin: Vector2) -> void:
	if alive:
		health.apply_damage(amount, origin, false)


func _on_damaged(amount: int, hit_position: Vector2, critical: bool) -> void:
	_flash = 1.0
	enemy_damaged.emit(self, amount, hit_position)
	SignalBus.enemy_damaged.emit(self, amount, hit_position, critical)


func _on_died(points: int) -> void:
	alive = false
	kills += 1
	ScoreManager.add_points_raw(points)
	var table := GameManager.table
	if table != null and data.mana_on_death > 0:
		table.add_mana(data.mana_on_death)
	AudioManager.play_sfx("enemy_death", 0.08, 0.0, 30)
	SignalBus.impact.emit(global_position, 0.8)
	_shape.set_deferred("disabled", true)
	sprite.visible = false
	_on_death_extra()
	enemy_died.emit(self, points)
	SignalBus.enemy_died.emit(self, points, global_position)
	if respawns:
		_respawn_left = data.respawn_seconds
	else:
		_respawn_left = 0.0


func _on_death_extra() -> void:
	pass


## Troca a arte (fase) e a vida máxima. target_px = tamanho do maior lado na mesa.
func apply_skin(texture: Texture2D, target_px: float, hp_scale: float) -> void:
	if texture != null:
		for c in sprite.get_children():
			c.queue_free()
		TableGeometry.fit_sprite(sprite, texture, target_px)
	var new_hp := maxi(1, int(round(data.max_hp * hp_scale)))
	health.max_hp = new_hp
	if alive:
		health.hp = new_hp


func revive() -> void:
	alive = true
	health.revive()
	_shape.set_deferred("disabled", false)
	sprite.visible = true
	sprite.modulate = Color.WHITE
	_on_revived()


func _on_revived() -> void:
	pass


## Desativa completamente (usado ao resetar a mesa).
func force_reset() -> void:
	_respawn_left = 0.0
	revive()
