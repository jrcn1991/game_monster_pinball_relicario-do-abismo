class_name Scoop
extends Area2D
## "Sacristia": buraco que captura a bola, mostra um prêmio e a cospe de volta.
## A mesa decide o prêmio via o sinal scoop_entered; pode segurar a bola (hold) para uma escolha.

signal scoop_entered(scoop: Scoop, ball: Ball)
signal ball_released(ball: Ball)

@export var radius: float = 20.0
@export var kick_direction: Vector2 = Vector2(0.35, -1.0)
@export var kick_strength: float = 900.0
@export var hold_seconds: float = 1.2

var held_ball: Ball = null
var _hold_left := 0.0
var _holding := false
var _sprite: Sprite2D
var _cooldown := 0.0
var lit_label := ""


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
	if ResourceLoader.exists("res://assets/art/props/scoop.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/scoop.png"), radius * 3.2)
	else:
		var poly := Polygon2D.new()
		poly.polygon = TableGeometry.circle_points(Vector2.ZERO, radius, 20)
		poly.color = Color(0.05, 0.05, 0.1)
		_sprite.add_child(poly)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


var _rest_timer := 0.0


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	elif not _holding:
		# Bola parada sobre o buraco depois do cooldown: cai nele.
		var resting := false
		for body in get_overlapping_bodies():
			if body is Ball and not (body as Ball).is_captive and not (body as Ball).on_ramp and (body as Ball).linear_velocity.length() < 40.0:
				resting = true
				_rest_timer += delta
				if _rest_timer > 0.4:
					_rest_timer = 0.0
					_on_body_entered(body)
				break
		if not resting:
			_rest_timer = 0.0
	if _holding and held_ball != null:
		if not is_instance_valid(held_ball):
			_holding = false
			held_ball = null
			return
		held_ball.reset_motion(position)
		if _hold_left > 0.0:
			_hold_left -= delta
			if _hold_left <= 0.0:
				release()


func _on_body_entered(body: Node) -> void:
	if not (body is Ball) or _cooldown > 0.0 or _holding:
		return
	var b := body as Ball
	if b.is_captive or b.on_ramp:
		return
	held_ball = b
	_holding = true
	_hold_left = hold_seconds
	call_deferred("_capture", b)


func _capture(b: Ball) -> void:
	if not is_instance_valid(b):
		_holding = false
		held_ball = null
		return
	b.freeze = true
	b.visible = false
	b.reset_motion(position)
	AudioManager.play_sfx("lock", 0.05, -4.0)
	scoop_entered.emit(self, b)


## Mantém a bola presa até release() (usado para a escolha da Indulgência).
func hold_indefinitely() -> void:
	_hold_left = -1.0


func release() -> void:
	if held_ball == null or not is_instance_valid(held_ball):
		_holding = false
		held_ball = null
		return
	var b := held_ball
	_holding = false
	held_ball = null
	_cooldown = 2.5
	b.freeze = false
	b.visible = true
	b.reset_motion(position + kick_direction.normalized() * (radius + Ball.RADIUS + 6.0))
	# Velocidade aplicada no próximo tick (o corpo acabou de sair do congelamento).
	var v := kick_direction.normalized() * kick_strength
	b.call_deferred("set_linear_velocity", v)
	b.call_deferred("apply_central_impulse", v * 0.2)
	AudioManager.play_sfx("launch", 0.1, -6.0)
	ball_released.emit(b)


func is_holding() -> bool:
	return _holding
