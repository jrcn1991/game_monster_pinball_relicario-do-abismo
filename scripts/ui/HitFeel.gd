class_name HitFeel
extends Node
## "Game feel" de impacto: hit-stop (congelamento curto), números de dano flutuantes e
## anéis de onda de choque. Respeita a opção de reduzir flashes/tremor (o hit-stop é mantido,
## pois não é um estímulo visual agressivo).

const HITSTOP_HIT := 0.045
const HITSTOP_CRIT := 0.09
const HITSTOP_KILL := 0.11
const HITSTOP_BOSS_PHASE := 0.25

var _table: Node2D
var _stop_left := 0.0
var _font_cache := {}


func setup(table: Node2D) -> void:
	_table = table
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.enemy_damaged.connect(_on_enemy_damaged)
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.boss_health_changed.connect(func(_c, _m): _hitstop(HITSTOP_CRIT))
	SignalBus.boss_phase_changed.connect(func(_p): _hitstop(HITSTOP_BOSS_PHASE))
	SignalBus.impact.connect(_on_impact)


func _process(delta: float) -> void:
	if _stop_left > 0.0:
		# delta já vem escalado por time_scale; usamos o relógio real.
		_stop_left -= delta / maxf(Engine.time_scale, 0.001)
		if _stop_left <= 0.0:
			Engine.time_scale = 1.0


func _hitstop(seconds: float) -> void:
	if GameManager.state == GameManager.State.PAUSED:
		return
	_stop_left = maxf(_stop_left, seconds)
	Engine.time_scale = 0.05


func _on_enemy_damaged(enemy: Node, amount: int, hit_position: Vector2, critical: bool) -> void:
	_hitstop(HITSTOP_CRIT if critical else HITSTOP_HIT)
	_damage_number(hit_position, str(amount), critical)
	_ring(hit_position, 70.0 if critical else 40.0, Color(0.96, 0.83, 0.37) if critical else Color(0.78, 0.49, 1.0))
	_punch(enemy, 1.35 if critical else 1.18)
	if critical:
		SignalBus.request_screen_shake.emit(0.6)
		SignalBus.request_flash.emit(Color(0.78, 0.49, 1.0), 0.3)
	else:
		SignalBus.request_screen_shake.emit(0.25)


func _on_enemy_died(_enemy: Node, points: int, position: Vector2) -> void:
	_hitstop(HITSTOP_KILL)
	_damage_number(position + Vector2(0, -26), "+" + ScoreManager.format_short(points * ScoreManager.multiplier), true)
	_ring(position, 120.0, Color(0.96, 0.83, 0.37))
	_ring(position, 70.0, Color(0.9, 0.22, 0.27))
	SignalBus.request_screen_shake.emit(0.8)


func _on_impact(position: Vector2, intensity: float) -> void:
	if intensity > 0.75:
		_ring(position, 50.0 * intensity, Color(0.78, 0.49, 1.0, 0.8))


func _punch(enemy: Node, amount: float) -> void:
	if not is_instance_valid(enemy):
		return
	var spr_v = enemy.get("sprite")
	if spr_v == null:
		spr_v = enemy.get_node_or_null("Sprite")
	if spr_v == null or not (spr_v is Node2D):
		return
	var spr: Node2D = spr_v
	if not spr.has_meta("base_scale"):
		spr.set_meta("base_scale", spr.scale)
	var base: Vector2 = spr.get_meta("base_scale")
	spr.scale = base * amount
	var tw := spr.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(spr, "scale", base, 0.35)


func _damage_number(pos: Vector2, text: String, critical: bool) -> void:
	if _table == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40 if critical else 28)
	l.add_theme_color_override("font_color", Color(0.96, 0.83, 0.37) if critical else Color(0.91, 0.87, 0.78))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos + Vector2(-30, -50)
	l.z_index = 50
	l.rotation = randf_range(-0.12, 0.12)
	_table.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(randf_range(-20, 20), -70), 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_property(l, "scale", Vector2(1.25, 1.25) if critical else Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(l.queue_free)


func _ring(pos: Vector2, radius: float, color: Color) -> void:
	if _table == null:
		return
	var r := ShockRing.new()
	r.position = pos
	r.max_radius = radius
	r.color = color
	r.z_index = 40
	_table.add_child(r)


class ShockRing:
	extends Node2D
	var max_radius := 60.0
	var color := Color.WHITE
	var _t := 0.0
	const LIFE := 0.32

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / LIFE, 0.0, 1.0)
		var rad := lerpf(8.0, max_radius, 1.0 - pow(1.0 - k, 2.0))
		var c := color
		c.a = (1.0 - k) * 0.9
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 40, c, lerpf(6.0, 1.5, k), true)
