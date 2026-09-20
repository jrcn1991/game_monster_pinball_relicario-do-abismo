class_name Plunger
extends Node2D
## Lançador com força carregável. Segurar "plunger" carrega; soltar lança.
## A força mínima sempre tira a bola da canaleta; a máxima alcança a órbita superior.

signal launched(ball: Ball, strength: float)

@export var min_impulse: float = 1450.0
@export var max_impulse: float = 2250.0
@export var charge_seconds: float = 1.1

var ball: Ball = null
var charge := 0.0
var charging := false
var enabled := true
var _rod: Polygon2D
var _rest_y := 0.0


func _ready() -> void:
	_rod = get_node_or_null("Rod") as Polygon2D
	if _rod == null:
		_rod = Polygon2D.new()
		_rod.name = "Rod"
		_rod.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(10, 70), Vector2(-10, 70)])
		_rod.color = Color(0.55, 0.38, 0.22)
		add_child(_rod)
	_rest_y = _rod.position.y


func _physics_process(delta: float) -> void:
	if ball == null or not enabled:
		charging = false
		charge = 0.0
		_rod.position.y = _rest_y
		return
	if Input.is_action_pressed("plunger"):
		if not charging:
			charging = true
			charge = 0.0
		charge = minf(charge + delta / charge_seconds, 1.0)
	elif charging:
		charging = false
		launch(charge)
	_rod.position.y = _rest_y + charge * 60.0


## Lança a bola com força 0..1. Usado também pelos testes automatizados.
func launch(strength: float) -> void:
	if ball == null:
		return
	strength = clampf(strength, 0.0, 1.0)
	var impulse := lerpf(min_impulse, max_impulse, strength)
	var b := ball
	ball = null
	charge = 0.0
	charging = false
	b.apply_central_impulse(Vector2(0.0, -impulse))
	AudioManager.play_sfx("launch", 0.05, 0.0)
	launched.emit(b, strength)


func has_ball() -> bool:
	return ball != null
