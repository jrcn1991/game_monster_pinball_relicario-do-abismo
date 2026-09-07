class_name Bumper
extends StaticBody2D
## Sino amaldiçoado: repele a bola com impulso radial e pontua a cada impacto válido.

@export var radius: float = 36.0
@export var kick_impulse: float = 750.0
@export var points: int = 250
@export var target_id: String = "bumper"

var _sprite: Sprite2D
var _flash := 0.0


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	physics_material_override = TableGeometry.rubber_material()
	var cs := get_node_or_null("Shape") as CollisionShape2D
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "Shape"
		add_child(cs)
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		var poly := Polygon2D.new()
		poly.polygon = TableGeometry.circle_points(Vector2.ZERO, radius, 28)
		poly.color = Color(0.55, 0.38, 0.22)
		add_child(poly)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		var s := 1.0 + _flash * 0.12
		scale = Vector2(s, s)
		if _sprite:
			_sprite.modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.0, 1.6, 2.4), _flash)


func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	var dir := (ball.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	ball.apply_central_impulse(dir * kick_impulse)
	ScoreManager.register_hit(target_id, points, global_position)
	_flash = 1.0
	AudioManager.play_sfx("bumper", 0.08, 0.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.6 + 0.3)
