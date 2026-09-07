class_name LockSaucer
extends Area2D
## Trava de bolas. Duas bolas travadas + a terceira entrando = multiball.

signal ball_entered_lock(ball: Ball)

@export var radius: float = 20.0
@export var points: int = 1000

var _sprite: Sprite2D
var _cooldown := 0.0


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
	if ResourceLoader.exists("res://assets/art/props/lock.png"):
		TableGeometry.fit_sprite(_sprite, load("res://assets/art/props/lock.png"), radius * 3.4)
	elif ResourceLoader.exists("res://assets/art/lock_saucer.png"):
		_sprite.texture = load("res://assets/art/lock_saucer.png")
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func _on_body_entered(body: Node) -> void:
	if body is Ball and _cooldown <= 0.0:
		_cooldown = 0.5
		ScoreManager.register_hit("lock", points, global_position)
		# Adiado: a mesa cria/remove corpos físicos em resposta (proibido durante o flush de queries).
		call_deferred("emit_signal", "ball_entered_lock", body)


## Chute para fora da trava (usado quando a trava não aceita a bola).
func kick_out(ball: Ball) -> void:
	ball.reset_motion(global_position + Vector2(0, 30))
	ball.apply_central_impulse(Vector2(120.0, 700.0))
