class_name Spinner
extends Area2D
## Spinner: placa giratória atravessando uma lane. Cada passagem rende pontos proporcionais
## à velocidade e a placa gira visualmente por alguns segundos.

@export var size: Vector2 = Vector2(44.0, 12.0)
@export var points_per_spin: int = 120
@export var target_id: String = "spinner_l"

var _sprite: Sprite2D
var _spin_speed := 0.0
var _spins_pending := 0.0
var spins := 0


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x, size.y + 16.0)
	cs.shape = rect
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/props/spinner.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/spinner.png"), size.x)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
		poly.color = Color(0.84, 0.66, 0.37)
		_sprite.add_child(poly)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _spin_speed > 0.0:
		# Escala vertical simula a placa girando em torno do eixo horizontal.
		_spins_pending += _spin_speed * delta
		var base_s: Vector2 = _sprite.get_meta("base_scale") if _sprite.has_meta("base_scale") else Vector2.ONE
		_sprite.scale = Vector2(base_s.x, base_s.y * absf(cos(_spins_pending * TAU)))
		_spin_speed = maxf(_spin_speed - delta * 6.0, 0.0)
		while _spins_pending >= 1.0:
			_spins_pending -= 1.0
			spins += 1
			ScoreManager.register_hit(target_id, points_per_spin, global_position)
			AudioManager.play_sfx("rollover", 0.2, -8.0, 40)


func _on_body_entered(body: Node) -> void:
	if body is Ball:
		var b := body as Ball
		_spin_speed = clampf(b.linear_velocity.length() / 120.0, 3.0, 18.0)
		ScoreManager.register_hit(target_id, points_per_spin, global_position)
		SignalBus.impact.emit(global_position, 0.25)
