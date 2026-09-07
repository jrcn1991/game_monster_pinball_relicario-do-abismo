class_name Ball
extends RigidBody2D
## A bola: projétil, arma e vida. RigidBody2D com rotação travada e CCD.
## Regra: nunca definimos a velocidade a cada frame. Exceções documentadas:
##  (1) limite de velocidade (estabilidade), (2) assistência de flipper (velocidade da superfície
##  do flipper transferida no contato), (3) recuperação de bola parada (impulso pequeno após 4 s).

signal hit_something(body: Node, impact_speed: float, position: Vector2)
signal stuck_rescue_requested(ball: Ball)

const RADIUS := 14.0
const MAX_SPEED := 2500.0
const STUCK_SPEED := 25.0
const STUCK_SECONDS := 4.0
const MAX_STUCK_RESCUES := 3
const TRAIL_LENGTH := 14
const FLIPPER_ASSIST := 0.95

var consecrated := false
var in_plunger_lane := true
var prev_velocity := Vector2.ZERO
var impact_speed_last := 0.0
var _hit_cooldowns: Dictionary = {}  # instance_id -> msec do clock físico
var _clock_msec := 0
var _stuck_timer := 0.0
var _stuck_rescues := 0
var _trail: Line2D
var _sprite: Sprite2D
var _halo: Sprite2D
var _rng := RandomNumberGenerator.new()
var id_label := 0  # para debug e testes
var anomalies := 0  # contagens de eventos anormais (fora da mesa etc.) para testes
var flipper_contacts := 0  # para testes


func _ready() -> void:
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	_rng.seed = GameManager.run_seed + id_label * 7919
	_sprite = get_node_or_null("Sprite") as Sprite2D
	_halo = get_node_or_null("Halo") as Sprite2D
	_trail = get_node_or_null("Trail") as Line2D
	if _trail:
		_trail.top_level = true
		_trail.clear_points()
	_update_colors()


func _physics_process(delta: float) -> void:
	_clock_msec += int(round(delta * 1000.0))
	# Detecção de bola parada (fora da canaleta do lançador).
	if not in_plunger_lane and GameManager.is_ball_in_play():
		if linear_velocity.length() < STUCK_SPEED:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_SECONDS:
				_stuck_timer = 0.0
				_stuck_rescues += 1
				if _stuck_rescues > MAX_STUCK_RESCUES:
					_stuck_rescues = 0
					stuck_rescue_requested.emit(self)
				else:
					# Recuperação documentada: pequeno impulso aleatório determinístico.
					var dir := Vector2(_rng.randf_range(-1.0, 1.0), -1.0).normalized()
					apply_central_impulse(dir * 220.0)
		else:
			_stuck_timer = 0.0
	# Limpeza de cooldowns antigos.
	if _hit_cooldowns.size() > 32:
		for k in _hit_cooldowns.keys():
			if _clock_msec - int(_hit_cooldowns[k]) > 1000:
				_hit_cooldowns.erase(k)


func _process(_delta: float) -> void:
	if _trail:
		_trail.add_point(global_position)
		while _trail.get_point_count() > TRAIL_LENGTH:
			_trail.remove_point(0)
	if _halo:
		var s := 1.0 + clampf(linear_velocity.length() / 2500.0, 0.0, 1.0) * 0.5
		_halo.scale = Vector2(s, s)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var v := state.linear_velocity
	# (1) Limite de velocidade para estabilidade.
	if v.length() > MAX_SPEED:
		v = v.normalized() * MAX_SPEED
	var contact_count := state.get_contact_count()
	for i in contact_count:
		var collider := state.get_contact_collider_object(i)
		if collider == null or not (collider is Node):
			continue
		var normal := state.get_contact_local_normal(i)  # aponta da superfície para a bola
		var contact_pos := state.get_contact_collider_position(i)
		# (2) Assistência de flipper: garante que a bola nunca "atravesse" a velocidade da pá.
		if collider is Flipper:
			flipper_contacts += 1
			var fl := collider as Flipper
			if fl.is_moving():
				var surf_v: Vector2 = fl.point_velocity(contact_pos)
				var sn := surf_v.dot(normal)
				var bn := v.dot(normal)
				if sn > bn:
					v += normal * (sn - bn) * FLIPPER_ASSIST
		# Interface Hittable: qualquer nó com on_ball_hit recebe o impacto (com cooldown por nó).
		if collider.has_method("on_ball_hit"):
			var cid := collider.get_instance_id()
			var last: int = int(_hit_cooldowns.get(cid, -100000))
			if _clock_msec - last >= Combat.INVULN_MS:
				_hit_cooldowns[cid] = _clock_msec
				var approach := absf(prev_velocity.dot(normal))
				var impact := maxf(approach, prev_velocity.length() * 0.35)
				impact_speed_last = impact
				collider.on_ball_hit(self, impact, contact_pos, normal)
				hit_something.emit(collider, impact, contact_pos)
	state.linear_velocity = v
	prev_velocity = v


func set_consecrated(value: bool) -> void:
	consecrated = value
	_update_colors()


func _update_colors() -> void:
	if _trail:
		_trail.default_color = Color(0.96, 0.83, 0.37, 0.85) if consecrated else Color(0.78, 0.49, 1.0, 0.6)
		_trail.width = 12.0 if consecrated else 8.0
	if _halo:
		_halo.modulate = Color(1.0, 0.85, 0.35, 0.55) if consecrated else Color(0.78, 0.49, 1.0, 0.35)
	if _sprite:
		_sprite.modulate = Color(1.0, 0.95, 0.75) if consecrated else Color.WHITE


## Usado ao servir/reposicionar (coordenadas LOCAIS da mesa): zera o estado dinâmico.
## Não é usado durante o jogo normal, apenas em serviço, trava, resgate e testes.
func reset_motion(new_local_position: Vector2) -> void:
	position = new_local_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	prev_velocity = Vector2.ZERO
	_stuck_timer = 0.0
	_hit_cooldowns.clear()
	if _trail:
		_trail.clear_points()
	var parent := get_parent() as Node2D
	var gpos := parent.to_global(new_local_position) if parent != null else new_local_position
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, gpos))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)


func speed() -> float:
	return linear_velocity.length()
