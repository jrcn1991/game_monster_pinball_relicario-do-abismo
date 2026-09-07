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


const WALL_THICKNESS := 18.0


## Quadrilátero/polígono convexo com ordem de vértices consistente (evita normais invertidas).
static func convex(points: PackedVector2Array) -> ConvexPolygonShape2D:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	var shape := ConvexPolygonShape2D.new()
	shape.points = hull
	return shape

## Cria uma parede (StaticBody2D) a partir de uma polilinha aberta.
## Cada trecho é um retângulo COM ESPESSURA (não um segmento sem espessura): a bola precisaria
## penetrar espessura + raio em um único tick para atravessar, o que elimina o tunneling.
## side: 0 = espessura centrada na linha; +1/-1 = espessura só para um lado (normal (dy,-dx)).
static func make_wall(parent: Node, points: PackedVector2Array, wall_name: String = "Wall",
		width: float = 6.0, color: Color = WALL_COLOR, material: PhysicsMaterial = null, side: int = 0,
		thickness: float = WALL_THICKNESS) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = wall_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = material if material != null else wall_material()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var d := (b - a).normalized()
		var n := Vector2(d.y, -d.x)
		var t0 := -thickness * 0.5
		var t1 := thickness * 0.5
		if side != 0:
			t0 = -1.0 * float(side) * 1.0  # 1 px para dentro: evita frestas na junção
			t1 = float(side) * thickness
			if t0 > t1:
				var tmp := t0; t0 = t1; t1 = tmp
		# Prolonga 1 px nas pontas para não deixar fresta entre trechos consecutivos.
		var a2 := a - d * 1.0
		var b2 := b + d * 1.0
		var cs := CollisionShape2D.new()
		cs.shape = convex(PackedVector2Array([a2 + n * t0, b2 + n * t0, b2 + n * t1, a2 + n * t1]))
		body.add_child(cs)
	# Traço estilizado: sombra escura larga + corpo de bronze + brilho fino.
	var shadow := Line2D.new()
	shadow.name = "Shadow"
	shadow.points = points
	shadow.width = width + 8.0
	shadow.default_color = Color(0.02, 0.02, 0.05, 0.85)
	shadow.joint_mode = Line2D.LINE_JOINT_ROUND
	shadow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
	shadow.z_index = -2
	body.add_child(shadow)
	var line := Line2D.new()
	line.name = "Visual"
	line.points = points
	line.width = width + 2.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = -1
	body.add_child(line)
	var hl := Line2D.new()
	hl.name = "Highlight"
	hl.points = points
	hl.width = maxf(width * 0.35, 2.0)
	hl.default_color = color.lightened(0.45)
	hl.default_color.a = 0.7
	hl.joint_mode = Line2D.LINE_JOINT_ROUND
	hl.begin_cap_mode = Line2D.LINE_CAP_ROUND
	hl.end_cap_mode = Line2D.LINE_CAP_ROUND
	hl.position = Vector2(-1.0, -1.5)
	body.add_child(hl)
	parent.add_child(body)
	return body


## Bloco sólido convexo (ex.: defletor encostado na parede): sem cantos agudos onde a bola trava.
static func make_solid(parent: Node, points: PackedVector2Array, solid_name: String = "Solid",
		color: Color = WALL_COLOR, material: PhysicsMaterial = null) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = solid_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.physics_material_override = material if material != null else wall_material()
	var cp := CollisionPolygon2D.new()
	cp.polygon = points
	body.add_child(cp)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(0.14, 0.14, 0.22)
	body.add_child(poly)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	var line := Line2D.new()
	line.points = closed
	line.width = 5.0
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
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
	var shadow := Polygon2D.new()
	shadow.polygon = circle_points(Vector2.ZERO, radius + 3.0, 20)
	shadow.color = Color(0.02, 0.02, 0.05, 0.85)
	body.add_child(shadow)
	var poly := Polygon2D.new()
	poly.polygon = circle_points(Vector2.ZERO, radius, 20)
	poly.color = color
	body.add_child(poly)
	var cap := Polygon2D.new()
	cap.polygon = circle_points(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.45, 12)
	cap.color = color.lightened(0.5)
	body.add_child(cap)
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


## Aplica o shader de balanço/brilho de idle a um sprite (chefe, inimigo).
static func apply_idle_shader(sprite: CanvasItem, sway: float, glow: float, speed: float, phase: float = 0.0) -> void:
	if sprite == null or not ResourceLoader.exists("res://assets/shaders/idle_sway.gdshader"):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/idle_sway.gdshader")
	mat.set_shader_parameter("sway_amount", sway)
	mat.set_shader_parameter("glow_amount", glow)
	mat.set_shader_parameter("sway_speed", speed)
	mat.set_shader_parameter("phase", phase)
	sprite.material = mat


## Aplica uma textura a um Sprite2D e escala para que o maior lado tenha target_px.
static func fit_sprite(sprite: Sprite2D, texture: Texture2D, target_px: float) -> void:
	if sprite == null or texture == null:
		return
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var m := maxf(float(texture.get_width()), float(texture.get_height()))
	var s := target_px / maxf(m, 1.0)
	sprite.scale = Vector2(s, s)
	sprite.set_meta("base_scale", sprite.scale)


static func concat(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(a)
	for p in b:
		out.append(p)
	return out
