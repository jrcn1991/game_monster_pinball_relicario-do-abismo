class_name StandupTarget
extends StaticBody2D
## Alvo fixo (stand-up) com luz: aceso = conta para o objetivo ativo.

signal target_hit(target: StandupTarget, impact_speed: float)

@export var size: Vector2 = Vector2(30.0, 12.0)
@export var points: int = 300
@export var target_id: String = "standup"

var lit := false
var _sprite: Sprite2D
var _flash := 0.0


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/props/standup.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/standup.png"), size.x * 1.2)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
		poly.color = Color(0.84, 0.66, 0.37)
		_sprite.add_child(poly)
	add_child(_sprite)
	_update_visual()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_update_visual()


func on_ball_hit(ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	if ball.is_captive:
		return
	_flash = 1.0
	ScoreManager.register_hit(target_id, points * (3 if lit else 1), hit_pos)
	AudioManager.play_sfx("target", 0.1, -4.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.4 + 0.2)
	target_hit.emit(self, impact_speed)
	_update_visual()


func set_lit(value: bool) -> void:
	lit = value
	_update_visual()


func _update_visual() -> void:
	var base := Color(1.0, 0.95, 0.7) if lit else Color(0.5, 0.5, 0.58)
	_sprite.modulate = base.lerp(Color(1.8, 1.6, 1.2), _flash)
