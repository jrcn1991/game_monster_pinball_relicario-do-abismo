class_name Projectile
extends Area2D
## Projétil inimigo lento e destrutível pela bola.

@export var speed: float = 160.0
@export var lifetime: float = 9.0
@export var radius: float = 11.0

var direction := Vector2.DOWN
var _age := 0.0
var _sprite: Sprite2D
var table_height := 1080.0


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/projectile.png"):
		_sprite.texture = load("res://assets/art/projectile.png")
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	position += direction * speed * delta
	_sprite.rotation += delta * 3.0
	if _age > lifetime or position.y > table_height - 60.0 or position.y < -40.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Ball:
		var ball := body as Ball
		if ball.consecrated:
			ScoreManager.register_hit("projectile", 200, global_position)
			AudioManager.play_sfx("projectile_break", 0.1, -4.0)
		else:
			# Projétil "fere" o jogador: quebra o combo e empurra a bola.
			ScoreManager.break_combo()
			ball.apply_central_impulse(direction * 260.0)
			AudioManager.play_sfx("projectile_hit_ball", 0.1, -2.0)
			SignalBus.ball_hit_by_projectile.emit(ball)
			SignalBus.request_flash.emit(Color(0.9, 0.22, 0.27), 0.25)
		SignalBus.projectile_destroyed.emit(global_position)
		queue_free()
