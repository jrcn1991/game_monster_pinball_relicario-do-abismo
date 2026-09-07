class_name DropTarget
extends StaticBody2D
## Alvo que "cai" ao ser acertado; o banco reseta quando todos caem.

signal dropped(target: DropTarget)

@export var size: Vector2 = Vector2(28.0, 14.0)
@export var points: int = 500
@export var target_id: String = "drop_1"

var is_down := false
var _shape: CollisionShape2D
var _visual: Node2D


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	_visual = get_node_or_null("Sprite")
	if _visual is Sprite2D and ResourceLoader.exists("res://assets/art/props/drop.png"):
		var spr := _visual as Sprite2D
		spr.rotation = 0.0
		TableGeometry.fit_sprite(spr, load("res://assets/art/props/drop.png"), size.x * 1.25)
	if _visual == null:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
		poly.color = Color(0.84, 0.66, 0.37)
		add_child(poly)
		_visual = poly


func on_ball_hit(_ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	if is_down:
		return
	is_down = true
	ScoreManager.register_hit(target_id, points, hit_pos)
	AudioManager.play_sfx("drop_target", 0.06, 0.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.5 + 0.3)
	_shape.set_deferred("disabled", true)
	if _visual:
		_visual.modulate = Color(1, 1, 1, 0.25)
	dropped.emit(self)


func reset_target() -> void:
	is_down = false
	_shape.set_deferred("disabled", false)
	if _visual:
		_visual.modulate = Color.WHITE
