class_name Flipper
extends AnimatableBody2D
## Flipper cinemático (sync_to_physics) com rotação limitada e velocidade angular constante.
## Sem teletransporte: o ângulo avança no máximo up_speed/down_speed por segundo.

@export var length: float = 115.0
@export var pivot_radius: float = 14.0
@export var tip_radius: float = 8.0
@export var rest_angle_deg: float = 28.0
@export var up_angle_deg: float = -26.0
@export var up_speed_deg: float = 1500.0
@export var down_speed_deg: float = 1000.0
@export var action_name: String = "flipper_left"
@export var is_right: bool = false

var pressed := false
var enabled := true  # falso durante TILT
var angular_velocity := 0.0  # rad/s
## Ângulo próprio (não normalizado). Node2D.rotation devolve valores em (-PI, PI], o que quebraria
## o flipper direito (repouso 152°, topo 206°).
var _angle := 0.0
var _prev_pressed := false
var _shape: CollisionShape2D
var _sprite: Sprite2D
var _poly: Polygon2D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 1 << 2
	collision_mask = 0
	_angle = deg_to_rad(rest_angle_deg)
	rotation = _angle
	_build_shape()
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite and _sprite.texture:
		# Sprite: pivô no pixel (16,16) de 128x32; ponta em ~118 -> 102 px de comprimento útil.
		_sprite.position = Vector2(64.0 - 16.0, 0.0) * (length / 102.0)
		_sprite.scale = Vector2(length / 102.0, 1.0)
	else:
		_poly = Polygon2D.new()
		_poly.polygon = _outline_points()
		_poly.color = Color(0.84, 0.66, 0.37)
		add_child(_poly)


func _outline_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var a := deg_to_rad(-90.0 + 180.0 * float(i) / float(steps))
		pts.append(Vector2(length, 0.0) + Vector2(cos(a), sin(a)) * tip_radius)
	for i in range(steps + 1):
		var a := deg_to_rad(90.0 + 180.0 * float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * pivot_radius)
	return pts


func _build_shape() -> void:
	_shape = get_node_or_null("Shape") as CollisionShape2D
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var convex := ConvexPolygonShape2D.new()
	convex.points = _outline_points()
	_shape.shape = convex


func _physics_process(delta: float) -> void:
	var want_up := pressed and enabled
	var target := deg_to_rad(up_angle_deg if want_up else rest_angle_deg)
	var speed := deg_to_rad(up_speed_deg if want_up else down_speed_deg)
	var old := _angle
	var new_rot := move_toward(old, target, speed * delta)
	angular_velocity = (new_rot - old) / delta if delta > 0.0 else 0.0
	if absf(new_rot - old) > deg_to_rad(2.0):
		_sweep_correct(old, new_rot)
	_angle = new_rot
	rotation = new_rot
	if pressed != _prev_pressed:
		_prev_pressed = pressed
		if pressed and enabled:
			AudioManager.play_sfx("flipper_up", 0.04, -4.0, 20)
		elif not pressed:
			AudioManager.play_sfx("flipper_down", 0.04, -10.0, 20)


## Mecanismo documentado de recuperação: a pá gira vários graus por tick de física. Uma bola que
## esteja dentro do setor varrido entre o ângulo antigo e o novo seria atravessada. Aqui ela é
## reposicionada logo à frente da face dianteira da pá e recebe, no mínimo, a velocidade da
## superfície nesse ponto. Só atua em bolas realmente dentro do setor varrido.
var sweep_corrections := 0

func _thickness_at(x: float) -> float:
	if x <= 0.0:
		return pivot_radius
	if x >= length:
		return tip_radius
	return lerpf(pivot_radius, tip_radius, x / length)


func _sweep_correct(old_rot: float, new_rot: float) -> void:
	var table := GameManager.table
	if table == null or not table.has_method("get_active_balls"):
		return
	var delta_rot := new_rot - old_rot
	var side := 1.0 if delta_rot > 0.0 else -1.0
	for ball in table.get_active_balls():
		if not is_instance_valid(ball) or ball.freeze:
			continue
		var b := ball as Ball
		var rel: Vector2 = b.global_position - global_position
		var dist := rel.length()
		if dist > length + tip_radius + Ball.RADIUS or dist < 0.001:
			continue
		var local_old := rel.rotated(-old_rot)
		var ang_old := atan2(local_old.y, local_old.x)
		var ang_new := ang_old - delta_rot
		var along := clampf(local_old.x, 0.0, length)
		var reach := _thickness_at(along) + Ball.RADIUS
		# Só corrige se a bola estava À FRENTE do movimento (ou encostada) e a pá passou pelo
		# centro dela neste tick. Bolas atrás do movimento (ex.: apoiadas na pá enquanto ela
		# desce) nunca são tocadas: o solver cuida do contato normal.
		if side * ang_old < -0.02 or side * ang_new >= 0.0:
			continue
		# Está dentro do setor varrido: reposiciona à frente da face dianteira da nova pose.
		var new_local := Vector2(along, side * (reach + 1.0))
		var new_global := global_position + new_local.rotated(new_rot)
		b.global_position = new_global
		PhysicsServer2D.body_set_state(b.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, new_global))
		var normal := Vector2(0.0, side).rotated(new_rot)
		var surf_v := Vector2(-new_local.y, new_local.x).rotated(new_rot) * angular_velocity
		var sn := surf_v.dot(normal)
		var bn := b.linear_velocity.dot(normal)
		if sn > bn:
			var v: Vector2 = b.linear_velocity + normal * (sn - bn) * 1.05
			b.linear_velocity = v
			PhysicsServer2D.body_set_state(b.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, v)
		sweep_corrections += 1


func set_pressed(value: bool) -> void:
	pressed = value


func is_moving() -> bool:
	return absf(angular_velocity) > 0.5


## Velocidade linear de um ponto global da pá (v = ω × r).
func point_velocity(global_point: Vector2) -> Vector2:
	var r := global_point - global_position
	return Vector2(-r.y, r.x) * angular_velocity


func is_up() -> bool:
	return is_equal_approx(_angle, deg_to_rad(up_angle_deg))


func is_at_rest() -> bool:
	return is_equal_approx(_angle, deg_to_rad(rest_angle_deg))


func tip_global_position() -> Vector2:
	return to_global(Vector2(length, 0.0))
