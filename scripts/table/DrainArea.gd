class_name DrainArea
extends Area2D
## Dreno: qualquer bola que entra aqui é perdida (a mesa decide se há ball save).

signal ball_drained(ball: Ball)


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Ball:
		ball_drained.emit(body)
