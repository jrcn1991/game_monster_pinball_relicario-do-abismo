extends Node
## Executor de testes headless. Uso:
##   godot --headless --path . res://tests/TestRunner.tscn
## Sai com código 0 se todos passaram, 1 caso contrário. Escreve tests/results/last_run.txt.

var _passed := 0
var _failed := 0
var _lines: Array[String] = []
var _current := ""
var _main: Node
var _table: GameTable
var _launch_count := 100
var _quick := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--launches="):
			_launch_count = int(arg.trim_prefix("--launches="))
		elif arg == "--quick":
			_quick = true
		elif arg.begins_with("--watchdog="):
			_watchdog_seconds = float(arg.trim_prefix("--watchdog="))
	AudioManager.muted_sfx = true
	# Salvamento isolado: os testes não devem poluir o recorde do jogador.
	SaveManager.save_path = "user://relicario_test.cfg"
	SaveManager.high_score = 0
	call_deferred("_run_all")


var _live: FileAccess
var _watchdog_seconds := 900.0
var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > _watchdog_seconds:
		_log("WATCHDOG: tempo excedido na seção '%s' (%.0f s)" % [_current, _elapsed])
		_failed += 1
		_finish()


func _log(msg: String) -> void:
	print(msg)
	_lines.append(msg)
	if _live == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
		_live = FileAccess.open("res://tests/results/live.log", FileAccess.WRITE)
	if _live:
		_live.store_line(msg)
		_live.flush()


func _check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		_log("  PASS  %s" % what)
	else:
		_failed += 1
		_log("  FAIL  %s" % what)


func _section(name: String) -> void:
	_current = name
	_log("\n== %s ==" % name)


## Congela a bola em um ponto seguro da mesa para testes de regras (não drena).
func _park(ball: Ball, local_pos: Vector2 = Vector2(380, 500)) -> void:
	ball.in_plunger_lane = false
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	ball.freeze = true
	ball.reset_motion(local_pos)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(ceil(s * Engine.physics_ticks_per_second)))


func _run_all() -> void:
	_log("Relicário do Abismo — testes automatizados (Godot %s)" % Engine.get_version_info().string)
	_log("physics ticks: %d" % Engine.physics_ticks_per_second)
	await _test_pure_functions()
	await _test_scene_loading()
	await _test_state_machine_and_serve()
	await _test_launches()
	await _test_flipper_power()
	await _test_multiball_and_drain_same_frame()
	await _test_lock_and_multiball()
	await _test_combat()
	await _test_boss()
	await _test_pause_restart()
	await _test_save()
	_finish()


# ---------------------------------------------------------------------------------
func _test_pure_functions() -> void:
	_section("Funções puras: dano, pontuação, formatação")
	var d := Combat.damage_for_impact(100.0, false, 1.0)
	_check(d.damage == 1 and not d.critical, "impacto lento -> dano mínimo 1")
	d = Combat.damage_for_impact(500.0, false, 1.0)
	_check(d.damage == 2 and not d.critical, "impacto médio -> dano 2")
	d = Combat.damage_for_impact(1200.0, false, 1.0)
	_check(d.damage == 3 and d.critical, "impacto rápido -> dano 3 crítico")
	d = Combat.damage_for_impact(1200.0, true, 1.0)
	_check(d.damage == 6, "Bola Consagrada dobra o dano (6)")
	_check(ScoreManager.format_short(999) == "999", "format_short 999")
	_check(ScoreManager.format_short(12345) == "12.3K", "format_short 12.3K: %s" % ScoreManager.format_short(12345))
	_check(ScoreManager.format_short(2_500_000) == "2.50M", "format_short 2.50M")
	_check(ScoreManager.format_full(1234567) == "1.234.567", "format_full 1.234.567")
	ScoreManager.reset()
	var p1 := ScoreManager.register_hit("a", 100)
	var p2 := ScoreManager.register_hit("a", 100)
	var p3 := ScoreManager.register_hit("b", 100)
	_check(ScoreManager.combo == 2, "combo cresce só com alvos diferentes (combo=%d)" % ScoreManager.combo)
	_check(p1 == 105 and p2 == 105 and p3 == 110, "bônus de combo aplicado nos pontos (%d,%d,%d)" % [p1, p2, p3])
	ScoreManager.reset()
	for i in 12:
		ScoreManager.register_hit("t%d" % i, 10)
	_check(ScoreManager.multiplier == 2, "multiplicador sobe após 12 alvos distintos (x%d)" % ScoreManager.multiplier)
	await _seconds(2.6)
	_check(ScoreManager.combo == 0, "combo expira após 2,5 s")
	# HealthComponent: invulnerabilidade e morte única.
	var hc := HealthComponent.new()
	hc.max_hp = 3
	add_child(hc)
	var deaths := [0]
	hc.died.connect(func(_p): deaths[0] += 1)
	var a1 := hc.apply_damage(1)
	var a2 := hc.apply_damage(1)  # mesmo instante -> ignorado
	_check(a1 == 1 and a2 == 0, "invulnerabilidade de 100 ms bloqueia dano duplo")
	await _seconds(0.15)
	hc.apply_damage(5)
	await _seconds(0.15)
	hc.apply_damage(5)
	_check(hc.is_dead and deaths[0] == 1, "morte emitida exatamente uma vez")
	hc.queue_free()


func _test_scene_loading() -> void:
	_section("Carregamento de cenas e recursos")
	var scenes := ["res://scenes/main/Main.tscn", "res://scenes/table/GameTable.tscn", "res://scenes/components/Ball.tscn",
		"res://scenes/components/Flipper.tscn", "res://scenes/components/Plunger.tscn", "res://scenes/components/Bumper.tscn",
		"res://scenes/components/Slingshot.tscn", "res://scenes/components/DropTarget.tscn", "res://scenes/enemies/EnemyBase.tscn",
		"res://scenes/enemies/SkeletonSentry.tscn", "res://scenes/enemies/AshBat.tscn", "res://scenes/enemies/StainedGlassGuardian.tscn",
		"res://scenes/bosses/FacelessBishop.tscn", "res://scenes/ui/HUD.tscn", "res://scenes/ui/PauseMenu.tscn", "res://scenes/ui/GameOver.tscn",
		"res://scenes/ui/MainMenu.tscn", "res://scenes/effects/Projectile.tscn", "res://scenes/effects/ManaFragment.tscn"]
	for s in scenes:
		var ps: PackedScene = load(s)
		_check(ps != null and ps.can_instantiate(), "cena carrega: %s" % s)
	var missing := 0
	for f in ["res://assets/art/ball.png", "res://assets/art/bishop.png", "res://assets/audio/sfx/bumper.wav", "res://assets/audio/music/ambient_loop.wav", "res://data/enemies/skeleton_sentry.tres"]:
		if not ResourceLoader.exists(f):
			missing += 1
			_log("  recurso ausente: %s" % f)
	_check(missing == 0, "recursos essenciais existem")
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)
	await _frames(3)
	_table = GameManager.table
	_check(_table != null, "GameTable registrada no GameManager")
	_table.input_override = true  # os testes controlam os flippers diretamente
	_check(_table.skeletons.size() == 3 and _table.bats.size() == 2 and _table.guardian != null and _table.boss != null, "3 esqueletos, 2 morcegos, guardião e chefe presentes")
	_check(_table.drop_bank.targets.size() == 3 and _table.lane_group.rollovers.size() == 4 and _table.runes.size() == 3, "3 drop targets, 4 lanes, 3 runas")


func _test_state_machine_and_serve() -> void:
	_section("Máquina de estados e serviço de bola")
	_check(GameManager.state == GameManager.State.MENU, "estado inicial MENU")
	GameManager.start_new_game(777)
	await _frames(2)
	_check(GameManager.state == GameManager.State.SERVE, "start_new_game -> SERVE")
	_check(_table.active_balls.size() == 1 and _table.plunger.has_ball(), "uma bola servida no lançador")
	var before := _table.active_balls.size()
	_table.serve_ball()
	_check(_table.active_balls.size() == before, "serve_ball duplicado é ignorado")
	_check(not _table.lane_gate.is_closed(), "portão da canaleta aberto ao servir")
	_table.plunger.launch(1.0)
	await _seconds(1.5)
	_check(GameManager.state == GameManager.State.PLAYING, "bola entrou em jogo -> PLAYING")
	_check(_table.lane_gate.is_closed(), "portão fecha após a bola sair da canaleta")
	_check(not _table.active_balls[0].in_plunger_lane, "bola marcada como fora da canaleta")
	# Transição inválida.
	var ok := GameManager.change_state(GameManager.State.GAME_OVER)
	_check(not ok and GameManager.state == GameManager.State.PLAYING, "transição inválida PLAYING->GAME_OVER recusada")
	_check(not GameManager.change_state(GameManager.State.PLAYING), "transição para o mesmo estado ignorada")


func _test_launches() -> void:
	_section("%d lançamentos automatizados (mín/méd/máx) com flippers automáticos" % _launch_count)
	GameManager.restart_game()
	await _frames(2)
	var drains := 0
	var max_speed := 0.0
	var anomalies := 0
	var total_frames := 0
	var stuck_events := 0
	var lane_fail := 0
	var flipper_contacts := 0
	var stuck_spots: Dictionary = {}  # posição arredondada -> contagem (diagnóstico)
	var press_left_frames := 0
	var press_right_frames := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var max_frames_per_launch := 120 * 20
	for i in _launch_count:
		# Garante uma bola no lançador.
		if not _table.plunger.has_ball():
			if _table.active_balls.is_empty():
				if GameManager.state in [GameManager.State.BALL_LOST, GameManager.State.GAME_OVER]:
					GameManager.restart_game()
					await _frames(2)
				else:
					_table.serve_ball()
			else:
				# bola ainda em jogo (não drenou no tempo): força dreno
				for b in _table.active_balls.duplicate():
					_table._on_ball_drained(b)
				await _frames(2)
				if GameManager.state in [GameManager.State.BALL_LOST, GameManager.State.GAME_OVER]:
					GameManager.restart_game()
				await _frames(2)
				if not _table.plunger.has_ball():
					_table.serve_ball()
		await _frames(2)
		var strength: float = [0.0, 0.5, 1.0][i % 3] if i < 30 else rng.randf()
		var ball: Ball = _table.plunger.ball
		var drained_before: int = _table.stats.drained
		_table.ball_save_left = 0.0  # sem ball save para medir drenos reais
		_table.plunger.launch(strength)
		var frames := 0
		var left_lane := false
		var ball_ref: WeakRef = weakref(ball)
		while frames < max_frames_per_launch:
			await get_tree().physics_frame
			frames += 1
			total_frames += 1
			_table.ball_save_left = 0.0
			if ball_ref.get_ref() == null or not _table.active_balls.has(ball):
				break
			flipper_contacts = maxi(flipper_contacts, ball.flipper_contacts)
			var p := ball.position
			var v := ball.linear_velocity.length()
			max_speed = maxf(max_speed, v)
			if not ball.in_plunger_lane:
				left_lane = true
			# Anomalias: fora dos limites geométricos da mesa.
			if p.x < -1.0 or p.x > GameTable.W + 1.0 or p.y < -1.0:
				anomalies += 1
			# IA de flipper: bate em pulsos de 12 frames quando a bola está na zona da pá
			# (descendo ou parada sobre ela); solta por pelo menos 20 frames entre pulsos.
			if press_left_frames > 0:
				press_left_frames -= 1
			if press_right_frames > 0:
				press_right_frames -= 1
			var in_zone := p.y > 900.0 and (ball.linear_velocity.y > -50.0)
			if in_zone and p.x < 385.0 and p.x > 200.0 and press_left_frames == 0:
				press_left_frames = 32
			if in_zone and p.x >= 375.0 and p.x < 560.0 and press_right_frames == 0:
				press_right_frames = 32
			_table.flipper_left.set_pressed(press_left_frames > 20)
			_table.flipper_right.set_pressed(press_right_frames > 20)
			if frames % 240 == 0 and v < 5.0 and not ball.in_plunger_lane:
				stuck_events += 1
				var key := "(%d,%d)" % [int(round(p.x / 20.0) * 20), int(round(p.y / 20.0) * 20)]
				stuck_spots[key] = int(stuck_spots.get(key, 0)) + 1
				if stuck_events % 4 == 0:
					_table.nudge(1 if p.x < 380.0 else -1)  # como um jogador faria
		_table.flipper_left.set_pressed(false)
		_table.flipper_right.set_pressed(false)
		if not left_lane and strength >= 0.5:
			lane_fail += 1
		if _table.stats.drained > drained_before:
			drains += 1
		if (i + 1) % 10 == 0:
			_log("  progresso: %d/%d lançamentos, %d drenos, %d frames" % [i + 1, _launch_count, drains, total_frames])
		if GameManager.state in [GameManager.State.BALL_LOST]:
			await _seconds(1.4)
		if GameManager.state == GameManager.State.GAME_OVER:
			GameManager.restart_game()
			await _frames(2)
	_log("  drenos: %d / %d | frames: %d (%.1f s/lançamento) | vel. máx: %.0f px/s | bolas paradas (amostras): %d | fora da mesa: %d | falha de saída da canaleta: %d | out_of_bounds: %d | resgates: %d | contatos c/ flipper (máx por bola): %d" % [drains, _launch_count, total_frames, float(total_frames) / 120.0 / maxf(_launch_count, 1), max_speed, stuck_events, anomalies, lane_fail, _table.stats.out_of_bounds, _table.stats.rescues, flipper_contacts])
	_check(flipper_contacts > 0, "flippers colidem com a bola")
	if not stuck_spots.is_empty():
		_log("  locais de bola parada (amostras a cada 2 s): %s" % str(stuck_spots))
	_check(anomalies == 0, "bola nunca saiu dos limites da mesa (tunneling)")
	_check(_table.stats.out_of_bounds == 0, "nenhuma bola fora da mesa detectada pela mesa")
	_check(max_speed <= Ball.MAX_SPEED + 1.0, "velocidade limitada a %.0f" % Ball.MAX_SPEED)
	_check(lane_fail == 0, "lançamentos médios/máximos sempre saem da canaleta")
	_check(stuck_events <= maxi(1, _launch_count / 10), "bola nunca fica presa na geometria (amostras paradas: %d)" % stuck_events)
	_check(drains >= 1 and _table.stats.drained >= 1, "ciclo dreno -> nova bola ocorre (%d drenos)" % drains)
	_check(_table.active_balls.size() <= 1, "sem bolas duplicadas ao final (%d)" % _table.active_balls.size())


func _test_flipper_power() -> void:
	_section("Força do flipper e ausência de atravessamento")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(0.0)
	await _seconds(0.3)
	var ball: Ball = _table.active_balls[0]
	# Coloca a bola caindo sobre o flipper esquerdo e bate.
	ball.in_plunger_lane = false
	ball.reset_motion(Vector2(300, 940))
	await _frames(2)
	var best_up := 0.0
	var pressed := false
	for f in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(ball) or not _table.active_balls.has(ball):
			break
		if not pressed and ball.position.y > 985.0:
			_table.flipper_left.set_pressed(true)
			pressed = true
		best_up = maxf(best_up, -ball.linear_velocity.y)
		if ball.position.y < 600.0:
			break
	_table.flipper_left.set_pressed(false)
	_log("  velocidade vertical máxima após flip: %.0f px/s" % best_up)
	_check(best_up > 900.0, "flipper lança a bola com força (> 900 px/s para cima)")
	_check(is_instance_valid(ball) and _table.active_balls.has(ball) and ball.position.y > -1.0, "bola não atravessou o flipper nem a mesa")
	# Dois flippers ao mesmo tempo.
	_table.flipper_left.set_pressed(true)
	_table.flipper_right.set_pressed(true)
	await _seconds(0.3)
	_check(_table.flipper_left.is_up() and _table.flipper_right.is_up(), "dois flippers pressionados simultaneamente chegam ao topo")
	_table.flipper_left.set_pressed(false)
	_table.flipper_right.set_pressed(false)
	await _seconds(0.3)
	# Bola contra a ponta do flipper em alta velocidade.
	if is_instance_valid(ball) and _table.active_balls.has(ball):
		ball.reset_motion(Vector2(350, 700))
		ball.apply_central_impulse(Vector2(0, 2400))
		await _frames(3)
		_table.flipper_left.set_pressed(true)
		await _seconds(1.0)
		_table.flipper_left.set_pressed(false)
		_check(_table.stats.out_of_bounds == 0, "bola rápida na ponta do flipper não atravessa")


func _test_multiball_and_drain_same_frame() -> void:
	_section("Multiball: drenar três bolas no mesmo frame perde só uma vida")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(1.0)
	await _seconds(1.0)
	_check(GameManager.state == GameManager.State.PLAYING, "em jogo antes do multiball")
	var b2 := _table.spawn_ball_at(Vector2(300, 500), Vector2(0, 0))
	var b3 := _table.spawn_ball_at(Vector2(500, 500), Vector2(0, 0))
	_table.multiball_active = true
	_check(_table.active_balls.size() == 3, "três bolas ativas")
	var balls_before := GameManager.balls_left
	_table.ball_save_left = 0.0
	for b in _table.active_balls.duplicate():
		_table._on_ball_drained(b)
	await _frames(2)
	_check(GameManager.balls_left == balls_before - 1, "perdeu exatamente uma vida (%d -> %d)" % [balls_before, GameManager.balls_left])
	_check(_table.active_balls.is_empty(), "lista de bolas ativas vazia")
	_check(not _table.multiball_active, "multiball encerrado")
	await _seconds(1.5)
	_check(GameManager.state == GameManager.State.SERVE and _table.active_balls.size() == 1, "nova bola servida uma única vez após BALL_LOST")
	# Ball save: dreno com save ativo não perde vida.
	_table.plunger.launch(1.0)
	await _seconds(1.0)
	_table.ball_save_left = 5.0
	var lives := GameManager.balls_left
	for b in _table.active_balls.duplicate():
		_table._on_ball_drained(b)
	await _seconds(0.5)
	_check(GameManager.balls_left == lives and _table.active_balls.size() == 1, "ball save devolve a bola sem perder vida")


func _test_lock_and_multiball() -> void:
	_section("Trava de bolas e multiball de três bolas")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(1.0)
	await _seconds(1.0)
	var ball: Ball = _table.active_balls[0]
	_table._on_ball_entered_lock(ball)
	await _frames(3)
	_check(_table.locked_balls == 1 and _table.active_balls.size() == 1 and _table.plunger.has_ball(), "1ª trava: bola travada e nova bola no lançador")
	_table.plunger.launch(1.0)
	await _seconds(1.0)
	_table._on_ball_entered_lock(_table.active_balls[0])
	await _frames(3)
	_check(_table.locked_balls == 2 and _table.plunger.has_ball(), "2ª trava: trava pronta")
	_table.plunger.launch(1.0)
	await _seconds(1.0)
	_table._on_ball_entered_lock(_table.active_balls[0])
	await _frames(3)
	_check(_table.multiball_active and _table.active_balls.size() == 3, "3ª entrada inicia multiball com 3 bolas (%d)" % _table.active_balls.size())
	_check(_table.locked_balls == 0, "contador de travas zerado")
	await _seconds(1.0)
	_check(_table.stats.out_of_bounds == 0, "bolas do multiball permanecem na mesa")


func _test_combat() -> void:
	_section("Combate: inimigos, mana, magia, projéteis")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(1.0)
	await _seconds(0.8)
	var ball: Ball = _table.active_balls[0]
	_park(ball)
	var sk: SkeletonSentry = _table.skeletons[0]
	var hp0: int = sk.health.hp
	sk.on_ball_hit(ball, 500.0, sk.position, Vector2.UP)
	_check(sk.health.hp == hp0 - 2, "esqueleto recebe dano proporcional ao impacto (%d -> %d)" % [hp0, sk.health.hp])
	sk.on_ball_hit(ball, 500.0, sk.position, Vector2.UP)
	_check(sk.health.hp == hp0 - 2, "dano duplo na mesma sobreposição ignorado")
	await _seconds(0.15)
	sk.on_ball_hit(ball, 1500.0, sk.position, Vector2.UP)
	_check(not sk.alive, "esqueleto morre e some")
	_check(_table.magic.mana > 0, "acertos geram mana (%d)" % _table.magic.mana)
	# Guardião: escudo reduz 80%.
	var g := _table.guardian
	var ghp: int = g.health.hp
	g.shield.on_ball_hit(ball, 500.0, g.position, Vector2.UP)
	_check(g.health.hp == ghp, "escudo do guardião anula impacto médio (80% de redução)")
	_table._on_rune_hit(_table.runes[0])
	_check(not g.shield.active, "runa desativa o escudo por 5 s")
	await _seconds(0.15)
	g.on_ball_hit(ball, 500.0, g.position, Vector2.UP)
	_check(g.health.hp == ghp - 2, "guardião sem escudo recebe dano cheio")
	# Magia.
	_table.magic.mana = 0
	_table.add_mana(100)
	_check(_table.magic.can_cast(), "100 de mana permite magia")
	var cast := _table.magic.try_cast()
	_check(cast and _table.magic.active and ball.consecrated, "Bola Consagrada ativa e bola consagrada")
	_check(_table.magic.mana == 0, "magia consome 100 de mana")
	_table.magic.time_left = 2.0
	_table.magic.mana = 100
	_table.magic.try_cast()
	_check(is_equal_approx(_table.magic.time_left, 8.0), "reativar renova para 8 s sem acumular")
	# Projétil destruído pela bola consagrada.
	var proj_scene: PackedScene = load("res://scenes/effects/Projectile.tscn")
	var pr: Projectile = proj_scene.instantiate()
	pr.position = ball.position + Vector2(0, -200)
	pr.direction = Vector2.DOWN
	_table.dynamic_layer.add_child(pr)
	pr._on_body_entered(ball)
	await _frames(2)
	_check(not is_instance_valid(pr), "projétil destruído ao tocar a bola consagrada")
	# Morcego solta fragmento de mana.
	var bat := _table.bats[0]
	bat.on_ball_hit(ball, 1500.0, bat.position, Vector2.UP)
	await _frames(2)
	var frags := 0
	for c in _table.dynamic_layer.get_children():
		if c is ManaFragment:
			frags += 1
	_check(not bat.alive and frags >= 1, "morcego morre e solta fragmento de mana")
	# Respawn de inimigo.
	sk._respawn_left = 0.01
	await _seconds(0.1)
	_check(sk.alive, "inimigo renasce após o tempo de respawn")


func _test_boss() -> void:
	_section("Chefe: selos, 3 fases, morte na transição, jackpot e vitória")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(1.0)
	await _seconds(0.8)
	var ball: Ball = _table.active_balls[0]
	_park(ball)
	var boss := _table.boss
	_check(boss.phase == FacelessBishop.Phase.SEALED, "chefe começa selado")
	boss.on_ball_hit(ball, 1500.0, boss.position, Vector2.UP)
	_check(boss.health.hp == FacelessBishop.TOTAL_HP, "chefe selado não recebe dano")
	_table._break_seal("targets")
	_table._break_seal("guardian")
	_check(not boss.is_active(), "2 selos não despertam o chefe")
	_table._break_seal("runes")
	await _frames(2)
	_check(boss.phase == FacelessBishop.Phase.PHASE1, "3 selos despertam o chefe (fase 1)")
	_check(GameManager.state == GameManager.State.BOSS_INTRO, "estado BOSS_INTRO")
	await _seconds(2.2)
	_check(GameManager.state == GameManager.State.BOSS_FIGHT, "estado BOSS_FIGHT após a intro")
	# Fase 1: ponto fraco inativo não causa dano; ativo causa.
	var inactive := 1 - boss.active_weak
	var hp := boss.health.hp
	boss.on_weakpoint_hit(inactive, ball, 1500.0, boss.position)
	_check(boss.health.hp == hp, "ponto fraco inativo não causa dano")
	await _seconds(0.15)
	boss.on_weakpoint_hit(boss.active_weak, ball, 1500.0, boss.position)
	_check(boss.health.hp == hp - 3, "ponto fraco ativo causa dano crítico (3)")
	# Leva à fase 2.
	while boss.phase == FacelessBishop.Phase.PHASE1:
		await _seconds(0.12)
		boss.on_weakpoint_hit(boss.active_weak, ball, 1500.0, boss.position)
	_check(boss.phase == FacelessBishop.Phase.PHASE2, "fase 2 atingida com HP <= 40 (hp=%d)" % boss.health.hp)
	await _frames(2)
	_check(_table.summoned.size() == 4, "fase 2 invoca 4 esqueletos")
	# Invulnerabilidade de transição: dano imediato ignorado.
	var hp2 := boss.health.hp
	boss.on_weakpoint_hit(0, ball, 1500.0, boss.position)
	_check(boss.health.hp == hp2, "invulnerável durante a transição de fase")
	await _seconds(1.6)
	# Mata um invocado no instante da mudança de fase (não deve travar).
	var summoned_one: SkeletonSentry = _table.summoned[0]
	while boss.phase == FacelessBishop.Phase.PHASE2:
		await _seconds(0.12)
		if boss.health.hp <= FacelessBishop.PHASE_HP + 3 and summoned_one.alive:
			summoned_one.health.apply_damage(99, summoned_one.position, false)
		boss.on_weakpoint_hit(0, ball, 1500.0, boss.position)
	_check(boss.phase == FacelessBishop.Phase.PHASE3, "fase 3 atingida (olho vulnerável)")
	_check(not summoned_one.alive, "inimigo destruído na transição de fase sem softlock")
	# Projéteis na fase 3.
	await _seconds(2.5)
	_check(boss.shots > 0, "chefe dispara projéteis lentos (%d)" % boss.shots)
	await _seconds(1.6)
	while boss.phase == FacelessBishop.Phase.PHASE3:
		await _seconds(0.12)
		boss.on_ball_hit(ball, 1500.0, boss.position, Vector2.UP)
	_check(boss.phase == FacelessBishop.Phase.DEFEATED, "chefe derrotado")
	await _frames(2)
	_check(_table.bonus_active and _table.jackpot_portal.active and ScoreManager.bonus_active, "sequência bônus e portal de jackpot ativos")
	var score_before := ScoreManager.score
	_table.jackpot_portal._on_body_entered(ball)
	_check(ScoreManager.score > score_before + 50000, "jackpot concedido (+%d)" % (ScoreManager.score - score_before))
	_table.bonus_left = 0.05
	await _seconds(0.2)
	_check(GameManager.state == GameManager.State.RESULTS and GameManager.victory, "fim da sequência bônus -> RESULTS com vitória")
	# Reinício durante/após o chefe.
	GameManager.restart_game()
	await _frames(2)
	_check(GameManager.state == GameManager.State.SERVE and boss.phase == FacelessBishop.Phase.SEALED and _table.summoned.is_empty(), "reinício limpa chefe, invocados e serve nova bola")


func _test_pause_restart() -> void:
	_section("Pausa, game over e reinício")
	GameManager.restart_game()
	await _frames(2)
	_table.plunger.launch(1.0)
	await _seconds(0.8)
	GameManager.pause_game()
	_check(GameManager.state == GameManager.State.PAUSED and get_tree().paused, "pausa congela a árvore")
	var pos := _table.active_balls[0].position
	await _frames(20)
	_check(_table.active_balls[0].position == pos, "bola não se move durante a pausa")
	GameManager.resume_game()
	_check(GameManager.state == GameManager.State.PLAYING and not get_tree().paused, "retomar volta ao estado anterior")
	# Reinício durante o chefe.
	_table._break_seal("targets"); _table._break_seal("guardian"); _table._break_seal("runes")
	await _frames(2)
	GameManager.restart_game()
	await _frames(2)
	_check(GameManager.state == GameManager.State.SERVE and GameManager.balls_left == 3, "reiniciar durante o chefe volta a SERVE com 3 bolas")
	# Game over após perder 3 bolas.
	for i in 3:
		if _table.plunger.has_ball():
			_table.plunger.launch(1.0)
		await _seconds(0.8)
		_table.ball_save_left = 0.0
		for b in _table.active_balls.duplicate():
			_table._on_ball_drained(b)
		await _seconds(1.5)
	_check(GameManager.state == GameManager.State.GAME_OVER and GameManager.balls_left == 0, "3 bolas perdidas -> GAME_OVER")
	GameManager.return_to_menu()
	await _frames(2)
	_check(GameManager.state == GameManager.State.MENU and _table.active_balls.is_empty(), "voltar ao menu limpa a mesa")
	GameManager.start_new_game(5)
	await _frames(2)
	_check(GameManager.state == GameManager.State.SERVE and _table.active_balls.size() == 1, "nova partida do menu")


func _test_save() -> void:
	_section("Salvamento de recorde e configurações")
	var old_hs := SaveManager.high_score
	SaveManager.high_score = 0
	var rec := SaveManager.submit_score(123456)
	_check(rec and SaveManager.high_score == 123456, "recorde registrado")
	SaveManager.music_volume = 0.42
	SaveManager.reduce_flash = true
	SaveManager.save_settings()
	SaveManager.music_volume = 1.0
	SaveManager.reduce_flash = false
	SaveManager.high_score = 0
	SaveManager.load_settings()
	_check(is_equal_approx(SaveManager.music_volume, 0.42) and SaveManager.reduce_flash and SaveManager.high_score == 123456, "configurações e recorde persistem em user://")
	SaveManager.high_score = maxi(old_hs, 0)
	SaveManager.music_volume = 0.8
	SaveManager.reduce_flash = false
	SaveManager.save_settings()
	# Nenhum carregamento por URL em runtime.
	var bad := 0
	for dir in ["res://scripts", "res://scripts/autoload", "res://scripts/table", "res://scripts/combat", "res://scripts/physics", "res://scripts/ui"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var txt := FileAccess.get_file_as_string(dir.path_join(f))
				if "http://" in txt or "https://" in txt or "HTTPRequest" in txt:
					bad += 1
	_check(bad == 0, "nenhum script carrega arquivos externos por URL")


func _finish() -> void:
	_log("\n==== RESULTADO: %d passaram, %d falharam ====" % [_passed, _failed])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/results"))
	var f := FileAccess.open("res://tests/results/last_run.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines))
		f.close()
	await get_tree().process_frame
	get_tree().quit(0 if _failed == 0 else 1)
