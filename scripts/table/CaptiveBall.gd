class_name CaptiveBall
extends Node2D
## "Sino": bola cativa num canal curto. O jogador bate nela por baixo; ela sobe e acerta o
## alvo do fim do canal (+1 no multiplicador de bônus). Volta por gravidade.

signal captive_hit(captive: CaptiveBall, strong: bool)

@export var channel_length: float = 70.0
@export var channel_width: float = 40.0
@export var captive_id: String = "captive_left"

var ball: Ball
var lit := true
var end_target: StaticBody2D
var hits := 0
var _sprite_bell: Sprite2D
var _flash := 0.0


func _ready() -> void:
	var G := TableGeometry
	var hw := channel_width * 0.5
	# Paredes do canal: laterais e teto (aberto embaixo). Espessura para fora.
	G.make_wall(self, PackedVector2Array([Vector2(-hw, 0), Vector2(-hw, -channel_length)]), "WallL", 5.0, G.WALL_HIGHLIGHT, null, 1, 10.0)
	G.make_wall(self, PackedVector2Array([Vector2(hw, -channel_length), Vector2(hw, 0)]), "WallR", 5.0, G.WALL_HIGHLIGHT, null, 1, 10.0)
	# Alvo do fim (teto): recebe o impacto da bola cativa.
	end_target = StaticBody2D.new()
	end_target.name = "EndTarget"
	end_target.collision_layer = 1
	end_target.collision_mask = 0
	end_target.physics_material_override = G.metal_material()
	end_target.set_script(preload("res://scripts/table/CaptiveEndTarget.gd"))
	end_target.set("owner_captive", self)
	var cs := CollisionShape2D.new()
	cs.shape = G.convex(PackedVector2Array([Vector2(-hw - 4, -channel_length - 12), Vector2(hw + 4, -channel_length - 12), Vector2(hw + 4, -channel_length), Vector2(-hw - 4, -channel_length)]))
	end_target.add_child(cs)
	add_child(end_target)
	_sprite_bell = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/props/captive_bell.png"):
		G.fit_sprite(_sprite_bell, load("res://assets/art/props/captive_bell.png"), channel_width * 1.1)
	else:
		var poly := Polygon2D.new()
		poly.polygon = G.circle_points(Vector2.ZERO, hw * 0.8, 16)
		poly.color = Color(0.84, 0.66, 0.37)
		_sprite_bell.add_child(poly)
	_sprite_bell.position = Vector2(0, -channel_length - 6)
	add_child(_sprite_bell)
	_update_visual()


## Cria a bola cativa (chamado pela mesa, que fornece a cena da bola).
func spawn_captive(ball_scene: PackedScene) -> void:
	if ball != null and is_instance_valid(ball):
		ball.queue_free()
	ball = ball_scene.instantiate()
	ball.name = "Captive"
	ball.is_captive = true
	ball.in_plunger_lane = false
	ball.position = Vector2(0, -Ball.RADIUS - 2.0)
	add_child(ball)
	ball.collision_mask = 1 | 2  # paredes e outras bolas
	ball.set_consecrated(false)
	if ball.has_node("Halo"):
		ball.get_node("Halo").visible = false


func reset_captive() -> void:
	if ball != null and is_instance_valid(ball):
		ball.reset_motion(Vector2(0, -Ball.RADIUS - 2.0))
	hits = 0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		_update_visual()


func on_end_hit(impact_speed: float) -> void:
	hits += 1
	_flash = 1.0
	var strong := impact_speed > 250.0
	ScoreManager.register_hit(captive_id, 800 if strong else 300, global_position)
	AudioManager.play_sfx("bumper", 0.15, -2.0, 60)
	SignalBus.impact.emit(Vector2(0, -channel_length) + position, 0.6 if strong else 0.3)
	captive_hit.emit(self, strong)
	_update_visual()


func set_lit(value: bool) -> void:
	lit = value
	_update_visual()


func _update_visual() -> void:
	var base := Color(1.0, 0.95, 0.75) if lit else Color(0.55, 0.55, 0.6)
	_sprite_bell.modulate = base.lerp(Color(1.8, 1.6, 1.2), _flash)
