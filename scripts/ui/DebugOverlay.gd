class_name DebugOverlay
extends Control
## F3: estado, FPS, ticks, bolas, velocidades, colisores. Desenha vetores de velocidade.

var _label: Label
var _table_origin := Vector2(550, 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = UITheme.make_label("", 15, Color(0.6, 1.0, 0.6))
	_label.position = Vector2(560, 110)
	add_child(_label)
	visible = false


func _process(_delta: float) -> void:
	visible = GameManager.debug_enabled
	if not visible:
		return
	var t := GameManager.table
	var lines := []
	lines.append("FPS %d | physics %d Hz | state %s | t=%.1fs | seed %d" % [Engine.get_frames_per_second(), Engine.physics_ticks_per_second, GameManager.State.keys()[GameManager.state], GameManager.game_time, GameManager.run_seed])
	if t != null:
		lines.append("bolas ativas %d | travadas %d | multiball %s | save %.1f | tilt %.2f%s | mana %d | magia %s" % [t.active_balls.size(), t.locked_balls, str(t.multiball_active), t.ball_save_left, t.tilt_meter, " TILT" if t.tilted else "", t.magic.mana, str(t.magic.active)])
		lines.append("stats %s" % str(t.stats))
		lines.append("selos %s | chefe fase %d hp %d/%d" % [str(t.seals), t.boss.phase, t.boss.health.hp, t.boss.health.max_hp])
		lines.append("flippers L %.0f°/%.0f rad/s  R %.0f°/%.0f rad/s" % [rad_to_deg(t.flipper_left.rotation), t.flipper_left.angular_velocity, rad_to_deg(t.flipper_right.rotation), t.flipper_right.angular_velocity])
		for b in t.active_balls:
			if is_instance_valid(b):
				lines.append("  bola %d pos (%.0f, %.0f) v %.0f px/s lane=%s consagrada=%s" % [b.id_label, b.position.x, b.position.y, b.speed(), str(b.in_plunger_lane), str(b.consecrated)])
	lines.append("log:")
	var n := GameManager.transition_log.size()
	for i in range(maxi(0, n - 6), n):
		lines.append("  " + GameManager.transition_log[i])
	_label.text = "\n".join(lines)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var t := GameManager.table
	if t == null:
		return
	for b in t.active_balls:
		if is_instance_valid(b):
			var p: Vector2 = t.to_global(b.position)
			draw_line(p, p + b.linear_velocity * 0.1, Color(0.4, 1.0, 0.4), 2.0)
			draw_arc(p, Ball.RADIUS, 0, TAU, 16, Color(1, 1, 0), 1.0)
	# Colisores principais em contorno.
	for f in [t.flipper_left, t.flipper_right]:
		var pts: PackedVector2Array = f._outline_points()
		var gp := PackedVector2Array()
		for q in pts:
			gp.append(t.to_global(f.to_global(q)))
		gp.append(gp[0])
		draw_polyline(gp, Color(0.2, 1.0, 1.0), 1.5)
