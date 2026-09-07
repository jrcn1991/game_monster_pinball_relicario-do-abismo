class_name JackpotPortal
extends Area2D
## Portal de jackpot: aparece após derrotar o chefe. Cada entrada = jackpot.

@export var radius: float = 34.0
@export var jackpot_base: int = 50000

var active := false
var _sprite: Sprite2D
var _cooldown := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	monitoring = true
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape.shape = circle
	add_child(_shape)
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/art/portal_boss.png"):
		_sprite.texture = load("res://assets/art/portal_boss.png")
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	set_active(false)


func _process(delta: float) -> void:
	if active:
		_sprite.rotation += delta * 1.5
	if _cooldown > 0.0:
		_cooldown -= delta


func set_active(value: bool) -> void:
	active = value
	set_deferred("visible", value)
	_shape.set_deferred("disabled", not value)


func _on_body_entered(body: Node) -> void:
	if not active or _cooldown > 0.0 or not (body is Ball):
		return
	_cooldown = 0.8
	var value := ScoreManager.add_points_raw(jackpot_base)
	SignalBus.jackpot_collected.emit(value)
	SignalBus.hud_message.emit(Loc.t("jackpot") % ScoreManager.format_short(value), 1.5)
	AudioManager.play_sfx("jackpot", 0.0, 0.0)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.5)
	var ball := body as Ball
	var dir := (ball.global_position - global_position).normalized()
	if dir.y > -0.3:
		dir = Vector2(dir.x * 0.5, 1.0).normalized()
	ball.apply_central_impulse(dir * 900.0)
