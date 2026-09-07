class_name TableGeometry
## Construtores de paredes, postes e arcos para a mesa. Colisores de segmento + Line2D visual.

const WALL_COLOR := Color(0.55, 0.38, 0.22)
const WALL_HIGHLIGHT := Color(0.84, 0.66, 0.37)


static func wall_material() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = 0.08
	m.bounce = 0.32
	return m


static func rubber_material() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = 0.2
	m.bounce = 0.85
	return m


static func metal_material() -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = 0.05
	m.bounce = 0.55
	return m


## Cria uma parede (StaticBody2D) a partir de uma polilinha aberta.
static func make_wall(parent: Node, points: PackedVector2Array, wall_name: String = "Wall",
		width: float = 6.0, color: Color = WALL_COLOR, material: PhysicsMaterial = null) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = material if material != null else wall_material()
	for i in range(points.size() - 1):
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = points[i]
		seg.b = points[i + 1]
		cs.shape = seg
		body.add_child(cs)
	var line := Line2D.new()
	line.name = "Visual"
	line.points = points
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	body.add_child(line)
	parent.add_child(body)
	return body


## Poste circular.
static func make_post(parent: Node, center: Vector2, radius: float, post_name: String = "Post",
		color: Color = WALL_HIGHLIGHT, material: PhysicsMaterial = null) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = post_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = material if material != null else metal_material()
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	body.add_child(cs)
	var poly := Polygon2D.new()
	poly.polygon = circle_points(Vector2.ZERO, radius, 20)
	poly.color = color
	body.add_child(poly)
	parent.add_child(body)
	return body


## Pontos de um arco elíptico. Ângulos em graus (Godot: y para baixo, 270° = topo).
static func arc_points(center: Vector2, rx: float, ry: float, a0_deg: float, a1_deg: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var a := deg_to_rad(lerpf(a0_deg, a1_deg, float(i) / float(steps)))
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func circle_points(center: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func concat(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(a)
	for p in b:
		out.append(p)
	return out
