class_name Exorcism
extends Node
## Lote C: "Exorcismo Final" (modo final). Requer as 7 Relíquias.
## Fase 1 (1 bola): os Vitrais eliminam Possessos, que ressuscitam até 3 em campo; 7 eliminações.
## Fase 2 (bolas ilimitadas, até 4): todos os Vitrais puxam a Alma para o jogador; o Abismo puxa
## de volta o tempo todo; bola parada no lançador acelera o Abismo. Vitória = 2.000.000.

signal state_changed(phase: int, kills: int, soul: float)
signal finished(won: bool)

const KILLS_NEEDED := 7
const MAX_POSSESSED := 3
const SOUL_START := 50.0
const SOUL_PER_SHOT := 9.0
const ABYSS_PULL := 1.6   # por segundo
const IDLE_PENALTY := 2.0 # multiplicador quando a bola está parada no lançador
const WIN_POINTS := 300000
const MAX_BALLS := 4

var table: Node = null
var phase := 0  # 0 inativo, 1, 2, 3 = terminado
var kills := 0
var soul := SOUL_START
var possessed: Array[Node] = []
var lit := false
var wins := 0
var losses := 0
var _idle_plunger := 0.0
var _spawn_positions := [Vector2(230, 300), Vector2(590, 300), Vector2(410, 360)]


func setup(t: Node) -> void:
	table = t


func reset_game() -> void:
	_clear_possessed()
	phase = 0
	kills = 0
	soul = SOUL_START
	lit = false
	state_changed.emit(phase, kills, soul)


func is_active() -> bool:
	return phase == 1 or phase == 2


func light() -> void:
	lit = true
	SignalBus.hud_message.emit("EXORCISMO FINAL ACESO: ACERTE O GUARDIÃO", 3.0)
	AudioManager.play_sfx("boss_phase", 0.0, 0.0)


func start() -> void:
	if is_active() or table == null:
		return
	lit = false
	phase = 1
	kills = 0
	soul = SOUL_START
	AudioManager.play_music("boss_loop", 1.0)
	AudioManager.play_sfx("portal_open", 0.0, 0.0)
	SignalBus.hud_message.emit("EXORCISMO FINAL — FASE 1: ELIMINE OS POSSESSOS", 3.0)
	SignalBus.request_flash.emit(Color(0.9, 0.22, 0.27), 0.7)
	_fill_possessed()
	state_changed.emit(phase, kills, soul)


func _fill_possessed() -> void:
	var alive := 0
	for p in possessed:
		if is_instance_valid(p) and p.alive:
			alive += 1
	while alive < MAX_POSSESSED and phase == 1:
		var idx := 0
		for i in possessed.size():
			if not is_instance_valid(possessed[i]) or not possessed[i].alive:
				idx = i
				break
		var pos: Vector2 = _spawn_positions[possessed.size() % _spawn_positions.size()] if possessed.size() < MAX_POSSESSED else _spawn_positions[idx]
		var sk: Node = table.skeleton_scene.instantiate()
		sk.name = "Possessed%d" % (kills + alive)
		sk.position = pos
		sk.respawns = false
		sk.lance_direction = Vector2(1, 0.5)
		sk.ready.connect(func():
			sk.apply_skin(table.current_stage().tex("enemy_static"), 90.0, 1.0)
			sk.apply_frames(table.current_stage().art_dir, "enemy_static", 90.0)
			sk.sprite.modulate = Color(1.6, 0.6, 0.6)
		)
		table.enemies_layer.call_deferred("add_child", sk)
		table.summoned.append(sk)
		possessed.append(sk)
		alive += 1


func _clear_possessed() -> void:
	for p in possessed:
		if is_instance_valid(p):
			p.queue_free()
	possessed.clear()


func _physics_process(delta: float) -> void:
	if phase != 2 or table == null:
		return
	var mult := 1.0
	if table.plunger != null and table.plunger.has_ball():
		_idle_plunger += delta
		if _idle_plunger > 2.0:
			mult = IDLE_PENALTY
	else:
		_idle_plunger = 0.0
	soul -= ABYSS_PULL * mult * delta
	state_changed.emit(phase, kills, soul)
	if soul <= 0.0:
		_finish(false)


## Qualquer Vitral acertado.
func on_vitral(_shot_id: String) -> void:
	if phase == 1:
		# Elimina o primeiro possesso vivo.
		for p in possessed:
			if is_instance_valid(p) and p.alive:
				p.health.apply_damage(99, p.position, false)
				break
		kills += 1
		ScoreManager.add_points_raw(5000)
		SignalBus.hud_message.emit("POSSESSO ELIMINADO %d/%d" % [kills, KILLS_NEEDED], 1.0)
		if kills >= KILLS_NEEDED:
			_begin_phase2()
		else:
			_fill_possessed()
		state_changed.emit(phase, kills, soul)
	elif phase == 2:
		soul = minf(soul + SOUL_PER_SHOT, 100.0)
		ScoreManager.add_points_raw(6000)
		state_changed.emit(phase, kills, soul)
		if soul >= 100.0:
			_finish(true)


func _begin_phase2() -> void:
	phase = 2
	_clear_possessed()
	soul = SOUL_START
	AudioManager.play_sfx("boss_phase", 0.0, 0.0)
	SignalBus.hud_message.emit("FASE 2: PUXE A ALMA! BOLAS ILIMITADAS", 3.0)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.6)
	# Mais bolas em jogo imediatamente.
	if table != null:
		while table.active_balls.size() < 2:
			table.spawn_ball_at(table.LOCK_POS + Vector2(30, 10), Vector2(200.0, 650.0))
		table.multiball_active = true
	state_changed.emit(phase, kills, soul)


## Chamado pela mesa quando uma bola drena durante a fase 2: volta ao lançador sem perder vida.
func on_ball_drained_phase2() -> void:
	if table != null and table.active_balls.size() < MAX_BALLS and phase == 2:
		table.call_deferred("serve_ball", false)


func _finish(won: bool) -> void:
	phase = 3
	_clear_possessed()
	if won:
		wins += 1
		ScoreManager.add_points(WIN_POINTS)
		AudioManager.play_sfx("victory", 0.0, 0.0)
		SignalBus.hud_message.emit("EXORCISMO COMPLETO! +300.000", 4.0)
		SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 1.0)
	else:
		losses += 1
		AudioManager.play_sfx("game_over", 0.0, -6.0)
		SignalBus.hud_message.emit("O ABISMO LEVOU A ALMA. COLETE AS 7 RELÍQUIAS DE NOVO", 4.0)
	if table != null:
		table.multiball_active = table.active_balls.size() > 1
		AudioManager.play_music(table.current_stage().music, 1.5)
	finished.emit(won)
	phase = 0
	state_changed.emit(phase, kills, soul)
