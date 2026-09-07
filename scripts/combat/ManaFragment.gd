class_name ManaFragment
extends Area2D
## Fragmento de mana solto por inimigos. Coletado pela bola.

@export var mana_amount: int = 15
@export var fall_speed: float = 110.0
@export var lifetime: float = 12.0

var _age := 0.0
var _sprite: Sprite2D
var table_height := 1080.0


func _ready() -> void:
	collision_layer = 1 << 7
	collision_mask = 1 << 1
	monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	cs.shape = circle
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/mana_fragment.png"):
		_sprite.texture = load("res://assets/art/mana_fragment.png")
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	position.y += fall_speed * delta
	position.x += sin(_age * 3.0) * 20.0 * delta
	_sprite.scale = Vector2.ONE * (1.0 + 0.15 * sin(_age * 8.0))
	if _age > lifetime or position.y > table_height - 40.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Ball:
		var table := GameManager.table
		if table != null and table.has_method("add_mana"):
			table.add_mana(mana_amount)
		ScoreManager.register_hit("mana_fragment", 250, global_position)
		AudioManager.play_sfx("mana_pickup", 0.1, -3.0)
		queue_free()
