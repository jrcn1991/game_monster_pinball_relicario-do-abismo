class_name RuneTarget
extends StaticBody2D
## Runa: alvo fixo que carrega mana e enfraquece o Guardião do Vitral.

signal rune_hit(rune: RuneTarget)

@export var radius: float = 20.0
@export var points: int = 400
@export var mana_amount: int = 25
@export var target_id: String = "rune_a"
@export var texture_path: String = "res://assets/art/rune_a.png"

var lit := false
var _sprite: Sprite2D
var _glow := 0.0


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 0
	physics_material_override = TableGeometry.metal_material()
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)
	_sprite.scale = Vector2(radius * 2.4 / 40.0, radius * 2.4 / 40.0)
	add_child(_sprite)
	_update_visual()


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta * 3.0, 0.0)
		_update_visual()


func on_ball_hit(_ball: Ball, impact_speed: float, hit_pos: Vector2, _normal: Vector2) -> void:
	lit = true
	_glow = 1.0
	ScoreManager.register_hit(target_id, points, hit_pos)
	AudioManager.play_sfx("target", 0.1, -3.0, 40)
	SignalBus.impact.emit(hit_pos, Combat.impact_intensity(impact_speed) * 0.4 + 0.2)
	rune_hit.emit(self)
	_update_visual()


func reset_rune() -> void:
	lit = false
	_update_visual()


func _update_visual() -> void:
	var base := Color(1.0, 1.0, 1.0) if lit else Color(0.55, 0.55, 0.6)
	_sprite.modulate = base.lerp(Color(1.6, 1.5, 1.0), _glow)
