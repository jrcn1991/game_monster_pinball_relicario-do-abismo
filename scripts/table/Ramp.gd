class_name Ramp
extends Node2D
## Rampa elevada: a bola entra pela boca, passa a colidir SÓ com os trilhos da rampa (camada 9),
## é desenhada por cima da mesa e sai no fim, voltando ao chão. Tiros fracos rolam de volta.

const RAMP_LAYER := 1 << 8

@export var path: PackedVector2Array = PackedVector2Array()
@export var width: float = 46.0
@export var ramp_id: String = "ramp_left"
@export var points: int = 2500
@export var color: Color = Color(0.78, 0.49, 1.0)

var completions := 0
var _enter: Area2D
var _exit: Area2D
var _rails: StaticBody2D


@export var smooth: bool = true
@export var bake_interval: float = 16.0


func _ready() -> void:
	if path.size() < 2:
		return
	if smooth and path.size() >= 3:
		path = _smooth_path(path)
	_build_rails()
	_build_floor()
	_enter = _make_area(path[0], (path[1] - path[0]).normalized(), "Enter")
	_enter.body_entered.connect(_on_enter)
	_enter.body_exited.connect(_on_enter_exited)
	var n := path.size()
	_exit = _make_area(path[n - 1], (path[n - 1] - path[n - 2]).normalized(), "Exit")
	_exit.body_entered.connect(_on_exit)


## Curva suave (Catmull-Rom via Curve2D) pelos pontos de controle: as dobras viram arcos
## de poucos graus por trecho, e a bola contorna a rampa em vez de ricochetear.
func _smooth_path(ctrl: PackedVector2Array) -> PackedVector2Array:
	var curve := Curve2D.new()
	curve.bake_interval = bake_interval
	for i in ctrl.size():
		var prev := ctrl[maxi(i - 1, 0)]
		var next := ctrl[mini(i + 1, ctrl.size() - 1)]
		var tangent := (next - prev) * 0.25
		if i == 0 or i == ctrl.size() - 1:
			tangent = Vector2.ZERO
		curve.add_point(ctrl[i], -tangent, tangent)
	var baked := curve.get_baked_points()
	if baked.size() < 3:
		return ctrl
	return baked


func _offset_line(sign_side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in path.size():
		var d: Vector2
		if i == 0:
			d = (path[1] - path[0]).normalized()
		elif i == path.size() - 1:
			d = (path[i] - path[i - 1]).normalized()
		else:
			d = ((path[i] - path[i - 1]).normalized() + (path[i + 1] - path[i]).normalized()).normalized()
		var nrm := Vector2(-d.y, d.x) * sign_side * width * 0.5
		out.append(path[i] + nrm)
	return out


func _build_rails() -> void:
	_rails = StaticBody2D.new()
	_rails.name = "Rails"
	_rails.collision_layer = RAMP_LAYER
	_rails.collision_mask = 0
	_rails.physics_material_override = TableGeometry.wall_material()
	for side: float in [-1.0, 1.0]:
		var line := _offset_line(side)
		for i in range(line.size() - 1):
			var a := line[i]
			var b := line[i + 1]
			var d := (b - a).normalized()
			var nrm := Vector2(d.y, -d.x)
			var cs := CollisionShape2D.new()
			var t: float = 12.0 * side  # espessura para fora da rampa
			cs.shape = TableGeometry.convex(PackedVector2Array([a - d, b + d, b + d + nrm * -t, a - d + nrm * -t]))
			_rails.add_child(cs)
		var vis := Line2D.new()
		vis.points = line
		vis.width = 7.0
		vis.default_color = Color(0.55, 0.38, 0.22)
		vis.joint_mode = Line2D.LINE_JOINT_ROUND
		vis.begin_cap_mode = Line2D.LINE_CAP_ROUND
		vis.end_cap_mode = Line2D.LINE_CAP_ROUND
		vis.z_index = 26
		_rails.add_child(vis)
		var hl := Line2D.new()
		hl.points = line
		hl.width = 2.5
		hl.default_color = Color(0.84, 0.66, 0.37, 0.9)
		hl.position = Vector2(-1, -1)
		hl.z_index = 27
		_rails.add_child(hl)
	add_child(_rails)


func _build_floor() -> void:
	var l := _offset_line(-1.0)
	var r := _offset_line(1.0)
	var poly := PackedVector2Array(l)
	for i in range(r.size() - 1, -1, -1):
		poly.append(r[i])
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = poly
	floor_poly.color = Color(color.r, color.g, color.b, 0.10)
	floor_poly.z_index = 25
	add_child(floor_poly)
	# Setas de direção ao longo da rampa
	if ResourceLoader.exists("res://assets/art/props/ramp_arrow.png"):
		var tex: Texture2D = load("res://assets/art/props/ramp_arrow.png")
		for i in range(2, path.size() - 3, maxi(2, path.size() / 8)):
			var s := Sprite2D.new()
			TableGeometry.fit_sprite(s, tex, width * 0.5)
			s.position = (path[i] + path[i + 1]) * 0.5
			s.rotation = (path[i + 1] - path[i]).angle() + PI / 2.0
			s.modulate.a = 0.6
			s.z_index = 25
			add_child(s)


func _make_area(pos: Vector2, dir: Vector2, area_name: String) -> Area2D:
	var a := Area2D.new()
	a.name = area_name
	a.collision_layer = 1 << 6
	a.collision_mask = 1 << 1
	a.position = pos
	a.rotation = dir.angle()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30.0, width + 8.0)
	cs.shape = rect
	a.add_child(cs)
	add_child(a)
	return a


func _on_enter(body: Node) -> void:
	if body is Ball:
		var b := body as Ball
		var dir := (path[1] - path[0]).normalized()
		var rel: Vector2 = b.position - path[0]
		var lateral := absf(rel.cross(dir))
		var v := b.linear_velocity
		# Só entra quem está alinhado com o canal e vindo na direção da rampa.
		if not b.on_ramp and lateral < width * 0.5 - 4.0 and v.length() > 1.0 and v.dot(dir) > 0.55 * v.length():
			b.enter_ramp(self)


## Segurança: uma bola "na rampa" que se afaste do canal volta imediatamente ao chão.
func _physics_process(_delta: float) -> void:
	var table := GameManager.table
	if table == null or path.size() < 2:
		return
	for ball in table.get_active_balls():
		if not is_instance_valid(ball):
			continue
		var b := ball as Ball
		if b.on_ramp and b.ramp == self:
			if _distance_to_path(b.position) > width * 0.5 + 8.0:
				b.exit_ramp()


func _distance_to_path(p: Vector2) -> float:
	var best := INF
	for i in range(path.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
		best = minf(best, p.distance_to(q))
	return best


func _on_enter_exited(body: Node) -> void:
	if body is Ball:
		var b := body as Ball
		var dir := (path[1] - path[0]).normalized()
		# Rolou de volta para fora da boca: volta ao chão.
		if b.on_ramp and b.ramp == self and b.linear_velocity.dot(dir) < 0.0:
			b.exit_ramp()


func _on_exit(body: Node) -> void:
	if body is Ball:
		var b := body as Ball
		if b.on_ramp and b.ramp == self:
			b.exit_ramp()
			completions += 1
			ScoreManager.register_hit(ramp_id, points, global_position)
			SignalBus.hud_message.emit(Loc.t("ramp"), 1.2)
			AudioManager.play_sfx("ball_save", 0.1, -6.0)
			SignalBus.impact.emit(_exit.global_position - global_position, 0.5)
			var table := GameManager.table
			if table != null:
				table.add_mana(10)
