class_name FacelessBishop
extends StaticBody2D
## Chefe Bispo Sem-Rosto. Três fases claramente sinalizadas.
## Fase 1: dois pontos fracos alternados. Fase 2: invoca quatro esqueletos e cria projéteis lentos.
## Fase 3: olho central vulnerável. Derrota: +25.000 e abre o portal de jackpot.

enum Phase { SEALED, PHASE1, PHASE2, PHASE3, DEFEATED }

signal phase_changed(phase: int)
signal defeated()
signal summon_requested(count: int)

const PHASE_HP := 20
const TOTAL_HP := PHASE_HP * 3
const TRANSITION_INVULN := 1.5
const WEAK_SWITCH_SECONDS := 4.0

@export var body_radius: float = 44.0
@export var weakpoint_radius: float = 16.0
@export var projectile_interval_p2: float = 3.0
@export var projectile_interval_p3: float = 4.0

var phase: Phase = Phase.SEALED
var health: HealthComponent
var weak_left: WeakPoint
var weak_right: WeakPoint
var active_weak := 0  # 0 esquerda, 1 direita (fase 1)
var _switch_timer := WEAK_SWITCH_SECONDS
var _transition_left := 0.0
var _proj_timer := 0.0
var _sprite: Sprite2D
var _eye: Sprite2D
var _shape: CollisionShape2D
var _flash := 0.0
var projectile_scene: PackedScene
var _rng := RandomNumberGenerator.new()
var shots := 0


func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	_rng.seed = GameManager.run_seed + 4242
	health = HealthComponent.new()
	health.name = "Health"
	health.max_hp = TOTAL_HP
	health.points_on_death = 25000
	health.invulnerability_ms = Combat.INVULN_MS
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	_shape.shape = circle
	add_child(_shape)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/bishop.png"):
		_sprite.texture = load("res://assets/art/bishop.png")
	add_child(_sprite)
	_eye = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/bishop_eye.png"):
		_eye.texture = load("res://assets/art/bishop_eye.png")
	_eye.position = Vector2(0, -6)
	_eye.visible = false
	add_child(_eye)
	weak_left = WeakPoint.new()
	weak_left.boss = self
	weak_left.side = 0
	weak_left.radius = weakpoint_radius
	weak_left.position = Vector2(-72, 28)
	add_child(weak_left)
	weak_right = WeakPoint.new()
	weak_right.boss = self
	weak_right.side = 1
	weak_right.radius = weakpoint_radius
	weak_right.position = Vector2(72, 28)
	add_child(weak_right)
	projectile_scene = load("res://scenes/effects/Projectile.tscn")
	_apply_phase_visuals()


func _physics_process(delta: float) -> void:
	if _transition_left > 0.0:
		_transition_left -= delta
		if _transition_left <= 0.0:
			health.external_invulnerable = false
	if phase == Phase.PHASE1:
		_switch_timer -= delta
		if _switch_timer <= 0.0:
			_switch_timer = WEAK_SWITCH_SECONDS
			active_weak = 1 - active_weak
			_apply_phase_visuals()
	if (phase == Phase.PHASE2 or phase == Phase.PHASE3) and GameManager.is_ball_in_play():
		_proj_timer -= delta
		if _proj_timer <= 0.0:
			_proj_timer = projectile_interval_p2 if phase == Phase.PHASE2 else projectile_interval_p3
			_fire()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_sprite.modulate = _base_modulate().lerp(Color(2.0, 1.4, 1.6), _flash)
	_sprite.position.y = sin(Time.get_ticks_msec() * 0.002) * 4.0
	_eye.position.y = _sprite.position.y - 6.0


func _base_modulate() -> Color:
	match phase:
		Phase.SEALED:
			return Color(0.45, 0.4, 0.55)
		Phase.DEFEATED:
			return Color(0.2, 0.2, 0.25, 0.5)
	return Color.WHITE


func _fire() -> void:
	var table := GameManager.table
	if table == null or projectile_scene == null:
		return
	shots += 1
	var p: Projectile = projectile_scene.instantiate()
	p.position = position + Vector2(0, body_radius + 10.0)
	p.direction = Vector2(_rng.randf_range(-0.5, 0.5), 1.0).normalized()
	p.speed = 170.0
	table.get_dynamic_layer().add_child(p)


# --- Ativação --------------------------------------------------------------------
func awaken() -> void:
	if phase != Phase.SEALED:
		return
	health.revive(TOTAL_HP)
	_set_phase(Phase.PHASE1)
	AudioManager.play_sfx("portal_open", 0.0, 0.0)
	SignalBus.boss_awakened.emit()
	SignalBus.boss_health_changed.emit(health.hp, health.max_hp)


func is_active() -> bool:
	return phase in [Phase.PHASE1, Phase.PHASE2, Phase.PHASE3]


func reset_boss() -> void:
	phase = Phase.SEALED
	health.revive(TOTAL_HP)
	health.external_invulnerable = false
	_transition_left = 0.0
	_shape.set_deferred("disabled", false)
	visible = true
	active_weak = 0
	_apply_phase_visuals()


func _set_phase(new_phase: Phase) -> void:
	if new_phase == phase:
		return
	phase = new_phase
	_apply_phase_visuals()
	phase_changed.emit(int(phase))
	SignalBus.boss_phase_changed.emit(int(phase))
	match phase:
		Phase.PHASE1:
			_switch_timer = WEAK_SWITCH_SECONDS
		Phase.PHASE2:
			_begin_transition()
			summon_requested.emit(4)
			SignalBus.hud_message.emit(Loc.t("boss_phase") % 2 + "  " + Loc.t("summon"), 2.5)
			_proj_timer = 1.5
		Phase.PHASE3:
			_begin_transition()
			SignalBus.hud_message.emit(Loc.t("boss_phase") % 3 + "  " + Loc.t("eye_open"), 2.5)
			_proj_timer = 2.0


func _begin_transition() -> void:
	health.external_invulnerable = true
	_transition_left = TRANSITION_INVULN
	_flash = 1.0
	AudioManager.play_sfx("boss_phase", 0.0, 0.0)
	SignalBus.request_flash.emit(Color(0.48, 0.17, 0.75), 0.5)
	SignalBus.request_screen_shake.emit(0.6)


func _apply_phase_visuals() -> void:
	_sprite.modulate = _base_modulate()
	match phase:
		Phase.SEALED:
			weak_left.set_state(WeakPoint.State.HIDDEN)
			weak_right.set_state(WeakPoint.State.HIDDEN)
			_eye.visible = false
		Phase.PHASE1:
			weak_left.set_state(WeakPoint.State.ACTIVE if active_weak == 0 else WeakPoint.State.INACTIVE)
			weak_right.set_state(WeakPoint.State.ACTIVE if active_weak == 1 else WeakPoint.State.INACTIVE)
			_eye.visible = false
		Phase.PHASE2:
			weak_left.set_state(WeakPoint.State.ACTIVE)
			weak_right.set_state(WeakPoint.State.ACTIVE)
			_eye.visible = false
		Phase.PHASE3:
			weak_left.set_state(WeakPoint.State.HIDDEN)
			weak_right.set_state(WeakPoint.State.HIDDEN)
			_eye.visible = true
		Phase.DEFEATED:
			weak_left.set_state(WeakPoint.State.HIDDEN)
			weak_right.set_state(WeakPoint.State.HIDDEN)
			_eye.visible = false


# --- Dano --------------------------------------------------------------------------
func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	match phase:
		Phase.SEALED:
			ScoreManager.register_hit("boss_sealed", 500, hit_pos)
			AudioManager.play_sfx("guardian_shield", 0.1, -6.0, 40)
		Phase.PHASE1, Phase.PHASE2:
			# Corpo blindado: só pontos.
			ScoreManager.register_hit("boss_body", 200, hit_pos)
			AudioManager.play_sfx("guardian_shield", 0.1, -4.0, 40)
			SignalBus.impact.emit(hit_pos, 0.3)
		Phase.PHASE3:
			_damage_from_ball(ball, impact_speed, hit_pos, 1.0, "boss_eye", 1000)
		Phase.DEFEATED:
			pass


func on_weakpoint_hit(side: int, ball: Ball, impact_speed: float, hit_pos: Vector2) -> void:
	match phase:
		Phase.PHASE1:
			if side == active_weak:
				_damage_from_ball(ball, impact_speed, hit_pos, 1.0, "boss_weak_%d" % side, 800)
				# Acertar o ponto ativo alterna imediatamente.
				active_weak = 1 - active_weak
				_switch_timer = WEAK_SWITCH_SECONDS
				_apply_phase_visuals()
			else:
				ScoreManager.register_hit("boss_weak_%d" % side, 100, hit_pos)
				AudioManager.play_sfx("guardian_shield", 0.1, -6.0, 40)
		Phase.PHASE2:
			_damage_from_ball(ball, impact_speed, hit_pos, 1.0, "boss_weak_%d" % side, 800)
		_:
			ScoreManager.register_hit("boss_body", 100, hit_pos)


func _damage_from_ball(ball: Ball, impact_speed: float, hit_pos: Vector2, scale_dmg: float, target_id: String, pts: int) -> void:
	var result := Combat.damage_for_impact(impact_speed, ball.consecrated, ScoreManager.combo_damage_bonus())
	var dmg := maxi(int(round(result.damage * scale_dmg)), 1)
	var applied: int = health.apply_damage(dmg, hit_pos, result.critical)
	ScoreManager.register_hit(target_id, pts, hit_pos)
	if applied > 0:
		AudioManager.play_sfx("boss_hit", 0.08, 0.0, 40)
		SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * (1.0 if result.critical else 0.7))
		var table := GameManager.table
		if table != null:
			table.add_mana(3)
			if ball.consecrated:
				table.magic.shockwave(hit_pos, self)


func take_area_damage(amount: int, origin: Vector2) -> void:
	if phase == Phase.PHASE3:
		health.apply_damage(amount, origin, false)


func _on_damaged(_amount: int, _hit_position: Vector2, _critical: bool) -> void:
	_flash = 1.0
	SignalBus.boss_health_changed.emit(health.hp, health.max_hp)
	# Transições de fase pelos limiares de vida (sinalizadas).
	if phase == Phase.PHASE1 and health.hp <= PHASE_HP * 2:
		_set_phase(Phase.PHASE2)
	elif phase == Phase.PHASE2 and health.hp <= PHASE_HP:
		_set_phase(Phase.PHASE3)


func _on_died(points: int) -> void:
	if phase == Phase.DEFEATED:
		return
	_set_phase(Phase.DEFEATED)
	ScoreManager.add_points_raw(points)
	AudioManager.play_sfx("boss_death", 0.0, 0.0)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.8)
	SignalBus.request_screen_shake.emit(1.0)
	SignalBus.hud_message.emit(Loc.t("boss_defeated"), 3.0)
	_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 1.2)
	defeated.emit()
	SignalBus.boss_defeated.emit()


class WeakPoint:
	extends StaticBody2D
	enum State { HIDDEN, INACTIVE, ACTIVE }
	var boss: FacelessBishop
	var side := 0
	var radius := 16.0
	var state: State = State.HIDDEN
	var _shape: CollisionShape2D
	var _sprite: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		collision_layer = 1 << 4
		collision_mask = 0
		physics_material_override = TableGeometry.metal_material()
		_shape = CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		_shape.shape = circle
		add_child(_shape)
		_sprite = Sprite2D.new()
		if ResourceLoader.exists("res://assets/art/weakpoint.png"):
			_sprite.texture = load("res://assets/art/weakpoint.png")
		add_child(_sprite)
		set_state(state)

	func _process(delta: float) -> void:
		_t += delta
		if state == State.ACTIVE:
			var s := 1.0 + 0.12 * sin(_t * 8.0)
			_sprite.scale = Vector2(s, s)

	func set_state(new_state: State) -> void:
		state = new_state
		_shape.set_deferred("disabled", state == State.HIDDEN)
		set_deferred("visible", state != State.HIDDEN)
		_sprite.scale = Vector2.ONE
		_sprite.modulate = Color.WHITE if state == State.ACTIVE else Color(0.4, 0.35, 0.5)

	func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
		if boss != null and state != State.HIDDEN:
			boss.on_weakpoint_hit(side, ball, impact_speed, hit_pos)
