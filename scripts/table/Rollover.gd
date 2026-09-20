class_name Rollover
extends Area2D
## Sensor de lane (rollover). Acende uma letra; o grupo decide o que fazer.

signal rolled(rollover: Rollover)

@export var letter: String = "E"
@export var points: int = 300
@export var size: Vector2 = Vector2(30.0, 22.0)

var lit := false
var _label: Label
var _poly: Polygon2D


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	add_child(cs)
	_poly = Polygon2D.new()
	_poly.polygon = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
	add_child(_poly)
	_label = Label.new()
	_label.text = letter
	_label.position = Vector2(-size.x / 2, -size.y / 2 - 2)
	_label.size = size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)
	body_entered.connect(_on_body_entered)
	_update_visual()


func _on_body_entered(body: Node) -> void:
	if body is Ball:
		if not lit:
			lit = true
			_update_visual()
		ScoreManager.register_hit("lane_" + letter, points, global_position)
		AudioManager.play_sfx("rollover", 0.1, -6.0, 60)
		rolled.emit(self)


func set_lit(value: bool) -> void:
	lit = value
	_update_visual()


func _update_visual() -> void:
	_poly.color = Color(0.96, 0.83, 0.37, 0.85) if lit else Color(0.22, 0.21, 0.3, 0.8)
	_label.add_theme_color_override("font_color", Color(0.04, 0.04, 0.07) if lit else Color(0.91, 0.87, 0.78))
