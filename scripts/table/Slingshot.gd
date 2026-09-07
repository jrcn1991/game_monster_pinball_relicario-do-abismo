class_name Slingshot
extends StaticBody2D
## Slingshot: triângulo com face ativa (hipotenusa) que chuta a bola.

@export var points_local: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0, 156), Vector2(85, 212)])
@export var kick_impulse: float = 620.0
@export var points: int = 150
@export var target_id: String = "sling_left"
@export var active_face_from: int = 0  # índice do vértice inicial da face ativa
@export var active_face_to: int = 2

var _flash := 0.0
var _band: Line2D


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	physics_material_override = TableGeometry.rubber_material()
	var cp := CollisionPolygon2D.new()
	cp.polygon = points_local
	add_child(cp)
	var poly := Polygon2D.new()
	poly.polygon = points_local
	poly.color = Color(0.22, 0.21, 0.30)
	add_child(poly)
	var outline := Line2D.new()
	var closed := PackedVector2Array(points_local)
	closed.append(points_local[0])
	outline.points = closed
	outline.width = 3.0
	outline.default_color = Color(0.55, 0.38, 0.22)
	add_child(outline)
	_band = Line2D.new()
	_band.points = PackedVector2Array([points_local[active_face_from], points_local[active_face_to]])
	_band.width = 7.0
	_band.default_color = Color(0.84, 0.66, 0.37)
	add_child(_band)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_band.default_color = Color(0.84, 0.66, 0.37).lerp(Color(1.0, 0.95, 0.6), _flash)
		_band.width = 7.0 + _flash * 5.0


func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, normal: Vector2) -> void:
	# Só a face ativa (hipotenusa) chuta: verificamos a normal do contato contra a normal da face.
	var a := to_global(points_local[active_face_from])
	var b := to_global(points_local[active_face_to])
	var face_dir := (b - a).normalized()
	var face_normal := Vector2(-face_dir.y, face_dir.x)
	# A normal da face deve apontar para fora do triângulo (para o lado onde a bola está).
	var centroid := to_global((points_local[0] + points_local[1] + points_local[2]) / 3.0)
	if face_normal.dot(a - centroid) < 0.0:
		face_normal = -face_normal
	if normal.dot(face_normal) < 0.6:
		return  # bateu na lateral inativa: apenas ricochete normal
	ball.apply_central_impulse(face_normal * kick_impulse)
	ScoreManager.register_hit(target_id, points, hit_pos)
	_flash = 1.0
	AudioManager.play_sfx("slingshot", 0.08, -2.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.5 + 0.2)
