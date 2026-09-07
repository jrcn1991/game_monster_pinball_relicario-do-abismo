class_name OutlanePost
extends StaticBody2D
## "Guardião da outlane": poste que sobe quando aceso e devolve a bola; consumido ao usar.

signal saved_ball(post: OutlanePost)

@export var radius: float = 9.0
@export var post_id: String = "post_left"

var lit := false
var _shape: CollisionShape2D
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	physics_material_override = TableGeometry.rubber_material()
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/props/guardian_post.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/guardian_post.png"), radius * 2.6)
	else:
		var poly := Polygon2D.new()
		poly.polygon = TableGeometry.circle_points(Vector2.ZERO, radius, 12)
		poly.color = Color(0.96, 0.83, 0.37)
		_sprite.add_child(poly)
	add_child(_sprite)
	set_lit(false)


func set_lit(value: bool) -> void:
	lit = value
	_shape.set_deferred("disabled", not value)
	_sprite.modulate = Color.WHITE if value else Color(1, 1, 1, 0.22)
	_sprite.scale = (_sprite.get_meta("base_scale") if _sprite.has_meta("base_scale") else Vector2.ONE) * (1.0 if value else 0.8)


func on_ball_hit(ball: Ball, _impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	if not lit or ball.is_captive:
		return
	set_lit(false)
	ball.apply_central_impulse(Vector2(0, -350.0))
	ScoreManager.register_hit(post_id, 1000, hit_pos)
	AudioManager.play_sfx("ball_save", 0.1, -2.0)
	SignalBus.hud_message.emit(Loc.t("post_save"), 1.2)
	saved_ball.emit(self)
