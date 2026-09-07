class_name LaneGate
extends StaticBody2D
## Portão de mão única no topo da canaleta do lançador: fechado depois que a bola sai.

@export var from_point: Vector2 = Vector2(760, 400)
@export var to_point: Vector2 = Vector2(820, 340)

var _shape: CollisionShape2D
var _line: Line2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	physics_material_override = TableGeometry.wall_material()
	_shape = CollisionShape2D.new()
	var d := (to_point - from_point).normalized()
	var n := Vector2(d.y, -d.x) * 5.0
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([from_point + n, to_point + n, to_point - n, from_point - n])
	_shape.shape = poly
	add_child(_shape)
	_line = Line2D.new()
	_line.points = PackedVector2Array([from_point, to_point])
	_line.width = 5.0
	_line.default_color = Color(0.84, 0.66, 0.37)
	add_child(_line)
	set_closed(false)


func set_closed(value: bool) -> void:
	_shape.set_deferred("disabled", not value)
	_line.visible = value


func is_closed() -> bool:
	return not _shape.disabled
