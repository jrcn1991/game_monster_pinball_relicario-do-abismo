class_name GameTable
extends Node2D
## A mesa completa: geometria, componentes, inimigos, chefe, bolas e regras de partida.
## Coordenadas locais: largura 820 (760 de playfield + 60 de canaleta), altura 1080.

const W := 820.0
const PLAY_W := 760.0
const H := 1080.0
const LANE_X := 760.0
const LANE_EXIT_Y := 330.0
const SERVE_POS := Vector2(790.0, 1020.0)
const LOCK_POS := Vector2(150.0, 330.0)
const BOSS_POS := Vector2(410.0, 190.0)
const BALL_SAVE_SECONDS := 8.0
const SERVE_GRACE_SECONDS := 4.0
const BONUS_SECONDS := 30.0
const TILT_PER_NUDGE := 0.34
const TILT_DECAY := 0.22
const TILT_LOCK_SECONDS := 3.0
const MULTIBALL_COUNT := 3

signal balls_in_play_changed(count: int)
signal stage_changed(stage: StageData, index: int, total: int)

var stages: Array[StageData] = []
var stage_index := 0
var _bg_sprite: Sprite2D

var ball_scene: PackedScene = preload("res://scenes/components/Ball.tscn")
var flipper_scene: PackedScene = preload("res://scenes/components/Flipper.tscn")
var bumper_scene: PackedScene = preload("res://scenes/components/Bumper.tscn")
var slingshot_scene: PackedScene = preload("res://scenes/components/Slingshot.tscn")
var drop_target_scene: PackedScene = preload("res://scenes/components/DropTarget.tscn")
var skeleton_scene: PackedScene = preload("res://scenes/enemies/SkeletonSentry.tscn")
var bat_scene: PackedScene = preload("res://scenes/enemies/AshBat.tscn")
var guardian_scene: PackedScene = preload("res://scenes/enemies/StainedGlassGuardian.tscn")
var bishop_scene: PackedScene = preload("res://scenes/bosses/FacelessBishop.tscn")

var static_layer: Node2D
var components_layer: Node2D
var enemies_layer: Node2D
var dynamic_layer: Node2D
var fx_layer: Node2D

var flipper_left: Flipper
var flipper_right: Flipper
var plunger: Plunger
var lane_gate: LaneGate
var drain: DrainArea
var lock_saucer: LockSaucer
var jackpot_portal: JackpotPortal
var drop_bank: DropTargetBank
var lane_group: LaneGroup
var runes: Array[RuneTarget] = []
var skeletons: Array[SkeletonSentry] = []
var bats: Array[AshBat] = []
var guardian: StainedGlassGuardian
var boss: FacelessBishop
var magic: MagicSystem
var summoned: Array[Node] = []

var active_balls: Array[Ball] = []
var locked_balls := 0
var multiball_active := false
var ball_save_left := 0.0
var ball_save_source := ""
var tilt_meter := 0.0
var tilt_locked_left := 0.0
var tilted := false
var seals := {"targets": false, "guardian": false, "runes": false}
var bonus_left := 0.0
var bonus_active := false
var boss_defeated_flag := false
var _next_ball_id := 1
var _pending_serve := false
var _tilt_warned := false
var _grant_serve_grace := true
## Quando true, a mesa NÃO lê o teclado/gamepad para os flippers (testes e autoplay controlam
## os flippers diretamente via set_pressed).
var input_override := false

# Métricas para testes
var stats := {"served": 0, "drained": 0, "saved": 0, "locked": 0, "multiballs": 0, "out_of_bounds": 0, "rescues": 0, "tilts": 0}


func _ready() -> void:
	GameManager.table = self
	_build_layers()
	_build_background()
	_build_walls()
	_build_flippers_and_plunger()
	_build_components()
	_build_enemies()
	_build_boss()
	_load_stages()
	magic = MagicSystem.new()
	magic.name = "Magic"
	magic.table = self
	add_child(magic)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.game_started.connect(_on_game_started)


# ---------------------------------------------------------------------------------
# Construção
# ---------------------------------------------------------------------------------
func _build_layers() -> void:
	static_layer = Node2D.new(); static_layer.name = "Static"; add_child(static_layer)
	components_layer = Node2D.new(); components_layer.name = "Components"; add_child(components_layer)
	enemies_layer = Node2D.new(); enemies_layer.name = "Enemies"; add_child(enemies_layer)
	dynamic_layer = Node2D.new(); dynamic_layer.name = "Dynamic"; add_child(dynamic_layer)
	fx_layer = Node2D.new(); fx_layer.name = "FX"; add_child(fx_layer)


func _load_stages() -> void:
	for i in range(1, 10):
		var path := "res://data/stages/stage%d.tres" % i
		if ResourceLoader.exists(path):
			stages.append(load(path))
	if stages.is_empty():
		stages.append(StageData.new())


func current_stage() -> StageData:
	return stages[clampi(stage_index, 0, stages.size() - 1)]


## Aplica arte, nomes e dificuldade da fase atual a todos os elementos.
func apply_stage(index: int) -> void:
	stage_index = clampi(index, 0, stages.size() - 1)
	var st := current_stage()
	var bg_tex := st.tex("background")
	if bg_tex != null and _bg_sprite != null:
		_bg_sprite.texture = bg_tex
		_bg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_bg_sprite.scale = Vector2(W / bg_tex.get_width(), H / bg_tex.get_height())
	for s in skeletons:
		s.apply_skin(st.tex("enemy_static"), 84.0, st.enemy_hp_scale)
		s.attack_interval_min = 6.0 * st.skeleton_attack_scale
		s.attack_interval_max = 9.0 * st.skeleton_attack_scale
	for b in bats:
		b.apply_skin(st.tex("enemy_flyer"), 76.0, st.enemy_hp_scale)
		b.move_speed = st.flyer_speed
	guardian.apply_skin(st.tex("enemy_guardian"), 118.0, st.enemy_hp_scale)
	guardian.shield.apply_skin(st.tex("guardian_shield"))
	guardian.fire_interval = 6.5 * st.projectile_interval_scale
	boss.apply_skin(st.tex("boss"), 250.0, st.boss_phase_hp, st.projectile_interval_scale)
	stage_changed.emit(st, stage_index, stages.size())


func advance_stage() -> void:
	# Limpa a mesa (mantém pontuação e bolas restantes), aplica a próxima fase e serve.
	var next := stage_index + 1
	var balls_now := GameManager.balls_left
	reset_table(false)
	GameManager.balls_left = mini(balls_now + 1, 5)
	GameManager.balls_changed.emit(GameManager.balls_left)
	apply_stage(next)
	AudioManager.play_music(current_stage().music, 1.0)
	SignalBus.hud_message.emit("FASE %d: %s" % [stage_index + 1, current_stage().display_name.to_upper()], 3.0)
	if GameManager.state != GameManager.State.SERVE:
		GameManager.change_state(GameManager.State.SERVE)
	serve_ball()


func _build_background() -> void:
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	_bg_sprite = bg
	if ResourceLoader.exists("res://assets/art/background_table.png"):
		bg.texture = load("res://assets/art/background_table.png")
	else:
		var rect := ColorRect.new()
		rect.size = Vector2(W, H)
		rect.color = Color(0.0353, 0.0392, 0.0706)
		bg.add_child(rect)
	bg.z_index = -10
	static_layer.add_child(bg)


func _build_walls() -> void:
	var G := TableGeometry
	# Contorno externo: parede esquerda, arco superior (semi-elipse) e parede direita.
	var outer := PackedVector2Array([Vector2(0, H), Vector2(0, 320)])
	outer = G.concat(outer, G.arc_points(Vector2(410, 320), 410, 300, 180, 360, 48))
	outer.append(Vector2(W, H))
	G.make_wall(static_layer, outer, "OuterWall", 8.0)
	# Divisória da canaleta do lançador + piso da canaleta.
	G.make_wall(static_layer, PackedVector2Array([Vector2(LANE_X, H), Vector2(LANE_X, 400)]), "LaneDivider", 6.0)
	G.make_wall(static_layer, PackedVector2Array([Vector2(LANE_X, 1040), Vector2(W, 1040)]), "LaneFloor", 6.0)
	# Portão de mão única no topo da canaleta.
	lane_gate = LaneGate.new()
	lane_gate.name = "LaneGate"
	lane_gate.from_point = Vector2(LANE_X, 400)
	lane_gate.to_point = Vector2(W, 340)
	static_layer.add_child(lane_gate)
	G.make_post(static_layer, Vector2(LANE_X, 400), 7.0, "PostLaneTop")
	# Divisórias inferiores (outlane / inlane / apron até o pivô do flipper).
	# A rampa do apron termina tangente ao topo do pivô do flipper (mesmo ângulo de repouso, 28°),
	# para a bola rolar da inlane direto para a pá sem degrau.
	G.make_wall(static_layer, PackedVector2Array([Vector2(60, 740), Vector2(60, 900), Vector2(245, 1000), Vector2(240, H)]), "LeftApron", 6.0)
	G.make_wall(static_layer, PackedVector2Array([Vector2(700, 740), Vector2(700, 900), Vector2(515, 1000), Vector2(520, H)]), "RightApron", 6.0)
	G.make_post(static_layer, Vector2(60, 740), 7.0, "PostL")
	G.make_post(static_layer, Vector2(700, 740), 7.0, "PostR")
	# Arcos internos da arena do chefe (abertos no topo e embaixo).
	var inner_left := G.arc_points(Vector2(410, 320), 320, 230, 180, 250, 16)
	var inner_right := G.arc_points(Vector2(410, 320), 320, 230, 290, 360, 16)
	G.make_wall(static_layer, inner_left, "InnerArcLeft", 6.0, Color(0.48, 0.17, 0.75))
	G.make_wall(static_layer, inner_right, "InnerArcRight", 6.0, Color(0.48, 0.17, 0.75))
	G.make_post(static_layer, inner_left[0], 7.0, "PostArcL", Color(0.78, 0.49, 1.0))
	G.make_post(static_layer, inner_right[inner_right.size() - 1], 7.0, "PostArcR", Color(0.78, 0.49, 1.0))
	G.make_post(static_layer, inner_left[inner_left.size() - 1], 7.0, "PostArcTL", Color(0.78, 0.49, 1.0))
	G.make_post(static_layer, inner_right[0], 7.0, "PostArcTR", Color(0.78, 0.49, 1.0))
	# Dreno.
	drain = DrainArea.new()
	drain.name = "Drain"
	drain.position = Vector2(W / 2.0, H + 60.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W + 200.0, 80.0)
	cs.shape = rect
	drain.add_child(cs)
	drain.ball_drained.connect(_on_ball_drained)
	static_layer.add_child(drain)


func _build_flippers_and_plunger() -> void:
	flipper_left = flipper_scene.instantiate()
	flipper_left.name = "FlipperLeft"
	flipper_left.position = Vector2(250, 1012)
	flipper_left.rest_angle_deg = 28.0
	flipper_left.up_angle_deg = -26.0
	flipper_left.action_name = "flipper_left"
	components_layer.add_child(flipper_left)
	flipper_right = flipper_scene.instantiate()
	flipper_right.name = "FlipperRight"
	flipper_right.position = Vector2(510, 1012)
	flipper_right.rest_angle_deg = 152.0
	flipper_right.up_angle_deg = 206.0
	flipper_right.action_name = "flipper_right"
	flipper_right.is_right = true
	components_layer.add_child(flipper_right)
	plunger = Plunger.new()
	plunger.name = "Plunger"
	plunger.position = Vector2(790, 1044)
	plunger.launched.connect(_on_plunger_launched)
	components_layer.add_child(plunger)


func _build_components() -> void:
	# Bumpers (sinos amaldiçoados).
	for i in 2:
		var b: Bumper = bumper_scene.instantiate()
		b.name = "Bumper%d" % i
		b.position = Vector2(270, 470) if i == 0 else Vector2(490, 470)
		b.target_id = "bumper_%d" % i
		components_layer.add_child(b)
	# Slingshots.
	var sl: Slingshot = slingshot_scene.instantiate()
	sl.name = "SlingLeft"
	# Borda inferior paralela à rampa do apron e afastada 45 px: a inlane passa por baixo.
	sl.position = Vector2(155, 790)
	sl.points_local = PackedVector2Array([Vector2(0, 0), Vector2(0, 110), Vector2(85, 156)])
	sl.active_face_from = 0
	sl.active_face_to = 2
	sl.target_id = "sling_left"
	components_layer.add_child(sl)
	var sr: Slingshot = slingshot_scene.instantiate()
	sr.name = "SlingRight"
	sr.position = Vector2(605, 790)
	sr.points_local = PackedVector2Array([Vector2(0, 0), Vector2(0, 110), Vector2(-85, 156)])
	sr.active_face_from = 0
	sr.active_face_to = 2
	sr.target_id = "sling_right"
	components_layer.add_child(sr)
	# Banco de drop targets (direita, voltado para o flipper esquerdo).
	drop_bank = DropTargetBank.new()
	drop_bank.name = "DropBank"
	drop_bank.position = Vector2(612, 372)
	drop_bank.rotation = deg_to_rad(45.0)
	for i in 3:
		var dt: DropTarget = drop_target_scene.instantiate()
		dt.name = "Drop%d" % i
		dt.position = Vector2(-38.0 + 38.0 * i, 0)
		dt.target_id = "drop_%d" % i
		drop_bank.add_child(dt)
	drop_bank.bank_completed.connect(_on_drop_bank_completed)
	components_layer.add_child(drop_bank)
	# Rollovers "ELOS".
	lane_group = LaneGroup.new()
	lane_group.name = "Lanes"
	var lane_defs := [["E", Vector2(30, 790)], ["L", Vector2(95, 790)], ["O", Vector2(665, 790)], ["S", Vector2(730, 790)]]
	for d in lane_defs:
		var r := Rollover.new()
		r.name = "Lane" + d[0]
		r.letter = d[0]
		r.position = d[1]
		lane_group.add_child(r)
	lane_group.completed.connect(_on_lanes_completed)
	components_layer.add_child(lane_group)
	# Runas.
	var rune_defs := [["rune_a", Vector2(78, 600)], ["rune_b", Vector2(682, 600)], ["rune_c", Vector2(190, 400)]]
	for d in rune_defs:
		var rune := RuneTarget.new()
		rune.name = d[0]
		rune.target_id = d[0]
		rune.texture_path = "res://assets/art/%s.png" % d[0]
		rune.position = d[1]
		rune.rune_hit.connect(_on_rune_hit)
		components_layer.add_child(rune)
		runes.append(rune)
	# Trava de bolas.
	lock_saucer = LockSaucer.new()
	lock_saucer.name = "Lock"
	lock_saucer.position = LOCK_POS
	lock_saucer.ball_entered_lock.connect(_on_ball_entered_lock)
	components_layer.add_child(lock_saucer)
	# Portal de jackpot (inativo até derrotar o chefe).
	jackpot_portal = JackpotPortal.new()
	jackpot_portal.name = "JackpotPortal"
	jackpot_portal.position = BOSS_POS
	components_layer.add_child(jackpot_portal)


func _build_enemies() -> void:
	var sk_defs := [[Vector2(150, 650), Vector2(1, -0.5)], [Vector2(380, 700), Vector2(-1, -0.6)], [Vector2(610, 650), Vector2(-1, -0.5)]]
	var idx := 0
	for d in sk_defs:
		var sk: SkeletonSentry = skeleton_scene.instantiate()
		sk.name = "Skeleton%d" % idx
		sk.position = d[0]
		sk.lance_direction = d[1]
		enemies_layer.add_child(sk)
		skeletons.append(sk)
		idx += 1
	var bat_defs := [[Vector2(140, 470), PackedVector2Array([Vector2(0, 0), Vector2(100, -70), Vector2(200, 0)])],
		[Vector2(620, 300), PackedVector2Array([Vector2(0, 0), Vector2(-80, -60), Vector2(-160, 0)])]]
	idx = 0
	for d in bat_defs:
		var bat: AshBat = bat_scene.instantiate()
		bat.name = "Bat%d" % idx
		bat.position = d[0]
		bat.waypoints = d[1]
		bat.enemy_id = "bat_%d" % idx
		enemies_layer.add_child(bat)
		bats.append(bat)
		idx += 1
	guardian = guardian_scene.instantiate()
	guardian.name = "Guardian"
	guardian.position = Vector2(380, 560)
	guardian.enemy_died.connect(_on_guardian_died)
	enemies_layer.add_child(guardian)


func _build_boss() -> void:
	boss = bishop_scene.instantiate()
	boss.name = "Bishop"
	boss.position = BOSS_POS
	boss.summon_requested.connect(_on_boss_summon)
	boss.defeated.connect(_on_boss_defeated)
	enemies_layer.add_child(boss)


# ---------------------------------------------------------------------------------
# Loop
# ---------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var in_game := GameManager.is_in_game()
	# Flippers.
	var can_flip := in_game and not tilted
	if not input_override:
		flipper_left.set_pressed(can_flip and Input.is_action_pressed("flipper_left"))
		flipper_right.set_pressed(can_flip and Input.is_action_pressed("flipper_right"))
	elif tilted:
		flipper_left.set_pressed(false)
		flipper_right.set_pressed(false)
	# TILT.
	if tilt_locked_left > 0.0:
		tilt_locked_left -= delta
		if tilt_locked_left <= 0.0:
			tilted = false
			flipper_left.enabled = true
			flipper_right.enabled = true
			SignalBus.tilt_recovered.emit()
	if tilt_meter > 0.0:
		tilt_meter = maxf(tilt_meter - TILT_DECAY * delta, 0.0)
		if tilt_meter < 0.5:
			_tilt_warned = false
	# Ball save.
	if ball_save_left > 0.0:
		ball_save_left -= delta
		SignalBus.ball_save_changed.emit(ball_save_left > 0.0, maxf(ball_save_left, 0.0))
	# Sequência bônus.
	if bonus_active:
		bonus_left -= delta
		if bonus_left <= 0.0:
			_end_bonus_sequence()
	# Bolas: saída da canaleta, retorno ao lançador, limites da mesa.
	for ball in active_balls.duplicate():
		if not is_instance_valid(ball):
			active_balls.erase(ball)
			continue
		var p: Vector2 = ball.position
		if ball.in_plunger_lane:
			if p.y < LANE_EXIT_Y or p.x < LANE_X - 10.0:
				ball.in_plunger_lane = false
				lane_gate.set_closed(true)
				if _grant_serve_grace and ball_save_left < SERVE_GRACE_SECONDS and ball_save_source == "":
					ball_save_left = SERVE_GRACE_SECONDS
					ball_save_source = "serve"
				_grant_serve_grace = false
				GameManager.on_ball_entered_play()
			elif plunger.ball == null and p.y > 990.0 and ball.linear_velocity.length() < 40.0:
				plunger.ball = ball  # caiu de volta: relança
		if p.x < -30.0 or p.x > W + 30.0 or p.y < -80.0 or p.y > H + 200.0:
			stats.out_of_bounds += 1
			push_warning("GameTable: bola fora da mesa em %s (anomalia física)" % str(p))
			_on_ball_stuck_rescue(ball)  # devolve ao lançador sem punir o jogador


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_in_game():
		return
	if event.is_action_pressed("magic"):
		if magic.try_cast():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("nudge_left"):
		nudge(-1)
	elif event.is_action_pressed("nudge_right"):
		nudge(1)


# ---------------------------------------------------------------------------------
# Bolas
# ---------------------------------------------------------------------------------
## grant_grace: bola nova (início/após perder bola) recebe alguns segundos de salvamento;
## bolas salvas ou devolvidas pela trava não recebem (evita salvamento infinito).
func serve_ball(grant_grace: bool = true) -> Ball:
	if plunger.ball != null:
		return plunger.ball  # já há bola no lançador: nunca duplicar
	_grant_serve_grace = grant_grace
	var ball: Ball = ball_scene.instantiate()
	ball.id_label = _next_ball_id
	_next_ball_id += 1
	ball.name = "Ball%d" % ball.id_label
	ball.position = SERVE_POS
	ball.in_plunger_lane = true
	ball.stuck_rescue_requested.connect(_on_ball_stuck_rescue)
	dynamic_layer.add_child(ball)
	active_balls.append(ball)
	plunger.ball = ball
	lane_gate.set_closed(false)
	magic.apply_to_new_ball(ball)
	stats.served += 1
	balls_in_play_changed.emit(active_balls.size())
	SignalBus.ball_served.emit(ball)
	return ball


func spawn_ball_at(pos: Vector2, impulse: Vector2) -> Ball:
	var ball: Ball = ball_scene.instantiate()
	ball.id_label = _next_ball_id
	_next_ball_id += 1
	ball.name = "Ball%d" % ball.id_label
	ball.position = pos
	ball.in_plunger_lane = false
	ball.stuck_rescue_requested.connect(_on_ball_stuck_rescue)
	dynamic_layer.add_child(ball)
	active_balls.append(ball)
	magic.apply_to_new_ball(ball)
	ball.apply_central_impulse(impulse)
	balls_in_play_changed.emit(active_balls.size())
	return ball


func _on_plunger_launched(_ball: Ball, _strength: float) -> void:
	pass


func _on_ball_drained(ball: Ball) -> void:
	if not active_balls.has(ball):
		return  # já processada (ex.: dreno e fora-da-mesa no mesmo frame)
	active_balls.erase(ball)
	stats.drained += 1
	if plunger.ball == ball:
		plunger.ball = null
	ball.queue_free()
	SignalBus.ball_drained.emit(ball, active_balls.size())
	balls_in_play_changed.emit(active_balls.size())
	if multiball_active and active_balls.size() <= 1:
		multiball_active = false
		SignalBus.multiball_ended.emit()
	if active_balls.size() > 0:
		AudioManager.play_sfx("drain", 0.05, -8.0)
		return  # multiball: só perde vida quando todas drenarem
	if ball_save_left > 0.0 and GameManager.is_ball_in_play():
		ball_save_left = 0.0
		ball_save_source = ""
		stats.saved += 1
		AudioManager.play_sfx("ball_save", 0.0, 0.0)
		SignalBus.hud_message.emit(Loc.t("ball_saved"), 1.5)
		SignalBus.ball_save_changed.emit(false, 0.0)
		call_deferred("_serve_and_kick")
		return
	AudioManager.play_sfx("drain", 0.0, 0.0)
	ball_save_left = 0.0
	ball_save_source = ""
	if GameManager.is_ball_in_play():
		SignalBus.hud_message.emit(Loc.t("ball_lost"), 1.2)
	GameManager.on_all_balls_lost()


## Bola salva: volta ao lançador e é lançada automaticamente.
func _serve_and_kick() -> void:
	var b := serve_ball(false)
	if b != null:
		await get_tree().physics_frame
		await get_tree().physics_frame
		if is_instance_valid(b) and plunger.ball == b:
			plunger.launch(0.75)


func _on_ball_stuck_rescue(ball: Ball) -> void:
	# Bola presa por muito tempo mesmo após impulsos: devolve ao lançador sem punição.
	if not active_balls.has(ball):
		return
	stats.rescues += 1
	if plunger.ball == null:
		ball.in_plunger_lane = true
		ball.reset_motion(SERVE_POS)
		plunger.ball = ball
		lane_gate.set_closed(false)
	else:
		_on_ball_drained(ball)


func get_active_balls() -> Array[Ball]:
	return active_balls


func get_dynamic_layer() -> Node2D:
	return dynamic_layer


func get_enemies() -> Array:
	var out: Array = []
	for s in skeletons: out.append(s)
	for b in bats: out.append(b)
	out.append(guardian)
	out.append(boss)
	for s in summoned:
		if is_instance_valid(s):
			out.append(s)
	return out


# ---------------------------------------------------------------------------------
# Nudge / TILT
# ---------------------------------------------------------------------------------
func nudge(direction: int) -> void:
	if tilted:
		return
	for b in active_balls:
		if is_instance_valid(b) and not b.in_plunger_lane:
			b.apply_central_impulse(Vector2(170.0 * direction, -70.0))
	AudioManager.play_sfx("nudge", 0.1, -4.0)
	SignalBus.request_screen_shake.emit(0.25)
	tilt_meter += TILT_PER_NUDGE
	SignalBus.tilt_warning.emit(tilt_meter)
	if tilt_meter >= 1.0:
		_trigger_tilt()
	elif tilt_meter >= 0.66 and not _tilt_warned:
		_tilt_warned = true
		AudioManager.play_sfx("tilt_warning", 0.0, -2.0)
		SignalBus.hud_message.emit(Loc.t("tilt_warning"), 1.0)


func _trigger_tilt() -> void:
	tilted = true
	stats.tilts += 1
	tilt_meter = 0.0
	tilt_locked_left = TILT_LOCK_SECONDS
	flipper_left.enabled = false
	flipper_right.enabled = false
	AudioManager.play_sfx("tilt", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("tilt"), TILT_LOCK_SECONDS)
	SignalBus.tilt_triggered.emit()
	ScoreManager.break_combo()


# ---------------------------------------------------------------------------------
# Alvos e missão
# ---------------------------------------------------------------------------------
func _on_lanes_completed() -> void:
	ball_save_left = maxf(ball_save_left, BALL_SAVE_SECONDS)
	ball_save_source = "lanes"
	SignalBus.ball_save_changed.emit(true, ball_save_left)


func _on_drop_bank_completed() -> void:
	_break_seal("targets")


func _on_rune_hit(rune: RuneTarget) -> void:
	add_mana(rune.mana_amount)
	if guardian != null:
		guardian.on_rune_hit()
	var all_lit := true
	for r in runes:
		if not r.lit:
			all_lit = false
	if all_lit:
		ScoreManager.add_points_raw(2000)
		for r in runes:
			r.reset_rune()
		_break_seal("runes")


func _on_guardian_died(_enemy: EnemyBase, _points: int) -> void:
	_break_seal("guardian")


func _break_seal(seal_id: String) -> void:
	if seals[seal_id] or boss.is_active() or boss_defeated_flag:
		return
	seals[seal_id] = true
	var count := 0
	for k in seals:
		if seals[k]:
			count += 1
	var label: String = {"targets": Loc.t("seal_targets"), "guardian": Loc.t("seal_guardian"), "runes": Loc.t("seal_runes")}[seal_id]
	SignalBus.seal_broken.emit(seal_id, count, seals.size())
	SignalBus.hud_message.emit(Loc.t("seal_broken") % label, 2.0)
	AudioManager.play_sfx("portal_open", 0.0, -6.0)
	ScoreManager.add_points_raw(5000)
	if count >= seals.size():
		_awaken_boss()


func _awaken_boss() -> void:
	if boss.is_active() or boss_defeated_flag:
		return
	boss.awaken()
	GameManager.on_boss_awakened()
	SignalBus.hud_message.emit(Loc.t("portal_open"), 3.0)
	SignalBus.mission_portal_opened.emit()
	SignalBus.request_flash.emit(Color(0.48, 0.17, 0.75), 0.6)
	AudioManager.play_music(current_stage().boss_music, 1.5)


func is_boss_active() -> bool:
	return boss != null and boss.is_active()


func _on_boss_summon(count: int) -> void:
	var positions := [Vector2(230, 300), Vector2(590, 300), Vector2(300, 140), Vector2(520, 140)]
	for i in mini(count, positions.size()):
		var sk: SkeletonSentry = skeleton_scene.instantiate()
		sk.name = "Summoned%d_%d" % [i, _next_ball_id]
		sk.position = positions[i]
		sk.respawns = false
		sk.lance_direction = Vector2(-1 if positions[i].x > 410 else 1, 0.5)
		enemies_layer.call_deferred("add_child", sk)
		summoned.append(sk)


func _on_boss_defeated() -> void:
	boss_defeated_flag = true
	GameManager.victory = stage_index >= stages.size() - 1
	bonus_active = true
	bonus_left = BONUS_SECONDS
	ScoreManager.bonus_active = true
	jackpot_portal.set_active(true)
	SignalBus.bonus_sequence_started.emit(BONUS_SECONDS)
	AudioManager.play_music("ambient_loop", 2.0)
	for s in summoned:
		if is_instance_valid(s) and s.alive:
			s.health.apply_damage(99, s.position, false)


func _end_bonus_sequence() -> void:
	bonus_active = false
	bonus_left = 0.0
	ScoreManager.bonus_active = false
	jackpot_portal.set_active(false)
	SignalBus.bonus_sequence_ended.emit()
	AudioManager.play_sfx("victory", 0.0, 0.0)
	if stage_index < stages.size() - 1:
		ScoreManager.add_points_raw(10000)
		advance_stage()
	else:
		GameManager.on_boss_defeated_and_bonus_finished()


# ---------------------------------------------------------------------------------
# Trava e multiball
# ---------------------------------------------------------------------------------
func _on_ball_entered_lock(ball: Ball) -> void:
	if not active_balls.has(ball):
		return
	if multiball_active or bonus_active or not GameManager.is_ball_in_play():
		lock_saucer.kick_out(ball)
		return
	if locked_balls < 2:
		locked_balls += 1
		stats.locked += 1
		active_balls.erase(ball)
		if plunger.ball == ball:
			plunger.ball = null
		ball.queue_free()
		balls_in_play_changed.emit(active_balls.size())
		AudioManager.play_sfx("lock", 0.0, 0.0)
		SignalBus.ball_locked.emit(locked_balls)
		if locked_balls >= 2:
			SignalBus.hud_message.emit(Loc.t("lock_ready"), 2.0)
		else:
			SignalBus.hud_message.emit(Loc.t("ball_locked") % locked_balls, 2.0)
		if active_balls.is_empty():
			# Nova bola no lançador, sem perder vida.
			call_deferred("serve_ball", false)
	else:
		start_multiball(ball)


func start_multiball(trigger_ball: Ball) -> void:
	locked_balls = 0
	multiball_active = true
	stats.multiballs += 1
	lock_saucer.kick_out(trigger_ball)
	var to_spawn := MULTIBALL_COUNT - active_balls.size()
	for i in to_spawn:
		var offset := Vector2(30.0 * (i + 1), 10.0)
		spawn_ball_at(LOCK_POS + offset, Vector2(200.0 + 120.0 * i, 650.0))
	ball_save_left = maxf(ball_save_left, BALL_SAVE_SECONDS)
	ball_save_source = "multiball"
	AudioManager.play_sfx("multiball_start", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("multiball"), 2.5)
	SignalBus.multiball_started.emit(active_balls.size())
	SignalBus.request_flash.emit(Color(0.78, 0.49, 1.0), 0.5)
	SignalBus.ball_save_changed.emit(true, ball_save_left)


# ---------------------------------------------------------------------------------
# Mana
# ---------------------------------------------------------------------------------
func add_mana(amount: int) -> void:
	magic.add_mana(amount)


# ---------------------------------------------------------------------------------
# Estado / reset
# ---------------------------------------------------------------------------------
func _on_game_started(_seed: int) -> void:
	reset_table()
	apply_stage(0)
	AudioManager.play_music(current_stage().music, 1.0)
	SignalBus.hud_message.emit("FASE 1: %s" % current_stage().display_name.to_upper(), 3.0)
	serve_ball()


func _on_state_changed(_old: int, new_state: int) -> void:
	if new_state == GameManager.State.SERVE and active_balls.is_empty() and plunger.ball == null and not _pending_serve:
		pass  # GameManager chama serve_ball explicitamente


func reset_table(full: bool = true) -> void:
	for b in active_balls:
		if is_instance_valid(b):
			b.queue_free()
	active_balls.clear()
	for c in dynamic_layer.get_children():
		c.queue_free()
	for s in summoned:
		if is_instance_valid(s):
			s.queue_free()
	summoned.clear()
	plunger.ball = null
	locked_balls = 0
	multiball_active = false
	ball_save_left = 0.0
	ball_save_source = ""
	tilt_meter = 0.0
	tilt_locked_left = 0.0
	tilted = false
	flipper_left.enabled = true
	flipper_right.enabled = true
	bonus_active = false
	bonus_left = 0.0
	boss_defeated_flag = false
	ScoreManager.bonus_active = false
	if full:
		stage_index = 0
	for k in seals:
		seals[k] = false
	drop_bank.reset_bank()
	lane_group.reset_lanes()
	for r in runes:
		r.reset_rune()
	for s in skeletons:
		s.force_reset()
	for b in bats:
		b.force_reset()
	guardian.force_reset()
	boss.reset_boss()
	jackpot_portal.set_active(false)
	lane_gate.set_closed(false)
	magic.reset()
	stats = {"served": 0, "drained": 0, "saved": 0, "locked": 0, "multiballs": 0, "out_of_bounds": 0, "rescues": 0, "tilts": 0}
	balls_in_play_changed.emit(0)
