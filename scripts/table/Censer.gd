class_name Censer
extends Area2D
## "Turíbulo": disco giratório no centro da mesa. A bola passando por cima o faz girar;
## cada meia-volta é um "Sopro". A mesa acumula os sopros (persistem entre bolas).

signal spun(half_turns: int)

@export var radius: float = 42.0

var _sprite: Sprite2D
var _angular := 0.0  # rad/s
var _accum := 0.0
var _last_hit_msec := 0


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/props/censer.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/censer.png"), radius * 2.2)
	else:
		var poly := Polygon2D.new()
		poly.polygon = TableGeometry.circle_points(Vector2.ZERO, radius, 24)
		poly.color = Color(0.55, 0.38, 0.22, 0.8)
		_sprite.add_child(poly)
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(-radius, -4), Vector2(radius, -4), Vector2(radius, 4), Vector2(-radius, 4)])
		bar.color = Color(0.84, 0.66, 0.37)
		_sprite.add_child(bar)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _angular > 0.01:
		_sprite.rotation += _angular * delta
		_accum += _angular * delta
		_angular = maxf(_angular - delta * 4.5, 0.0)
		while _accum >= PI:
			_accum -= PI
			spun.emit(1)


func _on_body_entered(body: Node) -> void:
	if body is Ball and not (body as Ball).is_captive and not (body as Ball).on_ramp:
		var now := Time.get_ticks_msec()
		if now - _last_hit_msec < 150:
			return
		_last_hit_msec = now
		var b := body as Ball
		_angular = clampf(_angular + b.linear_velocity.length() / 45.0, 4.0, 40.0)
		ScoreManager.register_hit("censer", 200, global_position)
		AudioManager.play_sfx("rollover", 0.2, -6.0, 60)
