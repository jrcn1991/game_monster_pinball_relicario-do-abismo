extends StaticBody2D
## Teto do canal da bola cativa: só reage ao impacto da própria bola cativa.

var owner_captive: Node


func on_ball_hit(ball: Ball, impact_speed: float, _hit_pos: Vector2, _normal: Vector2) -> void:
	if ball.is_captive and owner_captive != null and owner_captive.has_method("on_end_hit"):
		owner_captive.on_end_hit(impact_speed)
