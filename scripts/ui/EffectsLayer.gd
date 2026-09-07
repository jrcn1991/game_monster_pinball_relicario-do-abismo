class_name EffectsLayer
extends Node2D
## Flash de tela, tremor e partículas de impacto com pooling e limites. Respeita acessibilidade.

const MAX_BURSTS := 24

var _flash_rect: ColorRect
var _flash_left := 0.0
var _flash_time := 0.0
var _shake := 0.0
var _table: Node2D
var _bursts: Array[CPUParticles2D] = []
var _burst_index := 0
var _rng := RandomNumberGenerator.new()


func setup(table: Node2D, canvas: CanvasLayer) -> void:
	_table = table
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_flash_rect)
	for i in MAX_BURSTS:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 22
		p.lifetime = 0.55
		p.explosiveness = 1.0
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 320.0
		p.gravity = Vector2(0, 500)
		p.scale_amount_min = 3.0
		p.scale_amount_max = 8.0
		p.color = Color(0.78, 0.49, 1.0)
		add_child(p)
		_bursts.append(p)
	SignalBus.impact.connect(_on_impact)
	SignalBus.request_flash.connect(_on_flash)
	SignalBus.request_screen_shake.connect(_on_shake)
	SignalBus.enemy_died.connect(func(_e, _p, pos): _burst(pos, 1.0, Color(0.96, 0.83, 0.37)))
	SignalBus.projectile_destroyed.connect(func(pos): _burst(pos, 0.5, Color(0.9, 0.22, 0.27)))


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		var a := clampf(_flash_left / maxf(_flash_time, 0.01), 0.0, 1.0)
		_flash_rect.color.a = a * (0.12 if SaveManager.reduce_flash else 0.35)
	elif _flash_rect.color.a > 0.0:
		_flash_rect.color.a = 0.0
	if _shake > 0.0 and _table != null:
		_shake = maxf(_shake - delta * 3.0, 0.0)
		var amp := _shake * (2.0 if SaveManager.reduce_shake else 14.0)
		_table.position = Vector2(550, 0) + Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp))
		if _shake <= 0.0:
			_table.position = Vector2(550, 0)


func _on_impact(pos: Vector2, intensity: float) -> void:
	_burst(pos, intensity, Color(0.78, 0.49, 1.0).lerp(Color(0.96, 0.83, 0.37), intensity))
	if intensity > 0.7:
		_on_shake(intensity * 0.4)


func _burst(local_pos: Vector2, intensity: float, color: Color) -> void:
	var p := _bursts[_burst_index]
	_burst_index = (_burst_index + 1) % MAX_BURSTS
	p.position = local_pos
	p.amount = int(clampf(8.0 + intensity * 24.0, 8.0, 32.0))
	p.color = color
	p.initial_velocity_max = 180.0 + 260.0 * intensity
	p.restart()
	p.emitting = true


func _on_flash(color: Color, strength: float) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	_flash_time = 0.12 + 0.25 * strength
	_flash_left = _flash_time


func _on_shake(strength: float) -> void:
	_shake = maxf(_shake, clampf(strength, 0.0, 1.0))
