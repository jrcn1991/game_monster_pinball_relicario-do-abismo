extends Node
## GameManager: estados da partida, bolas, pausa e reinício. Toda transição passa por change_state.

enum State { BOOT, MENU, SERVE, PLAYING, BALL_LOST, BOSS_INTRO, BOSS_FIGHT, PAUSED, GAME_OVER, RESULTS }

signal state_changed(old_state: State, new_state: State)
signal balls_changed(balls_left: int)
signal game_started(seed: int)
signal game_ended(victory: bool, final_score: int, is_record: bool)

const STARTING_BALLS := 3
const MAX_TRANSITION_LOG := 200

var state: State = State.BOOT
var previous_state: State = State.BOOT
var balls_left: int = STARTING_BALLS
var run_seed: int = 0
var rng := RandomNumberGenerator.new()
var victory: bool = false
var transition_log: Array[String] = []
var debug_enabled: bool = false
var table: Node = null  # GameTable ativo (registrado pela própria mesa)
var _resume_state: State = State.PLAYING
var headless: bool = false
var game_time: float = 0.0
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	headless = DisplayServer.get_name() == "headless"
	_setup_input_map()
	change_state(State.MENU)


func _physics_process(delta: float) -> void:
	if state == State.PLAYING or state == State.BOSS_FIGHT or state == State.SERVE:
		game_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_enabled = not debug_enabled
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if is_in_game():
			pause_game()
			get_viewport().set_input_as_handled()
		elif state == State.PAUSED:
			resume_game()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------
func change_state(new_state: State) -> bool:
	if new_state == state:
		_log("ignorado (mesmo estado): %s" % State.keys()[new_state])
		return false
	if _transitioning:
		push_warning("GameManager: transição reentrante ignorada: %s -> %s" % [State.keys()[state], State.keys()[new_state]])
		return false
	if not _is_valid_transition(state, new_state):
		push_warning("GameManager: transição inválida %s -> %s" % [State.keys()[state], State.keys()[new_state]])
		return false
	_transitioning = true
	previous_state = state
	state = new_state
	_log("%s -> %s" % [State.keys()[previous_state], State.keys()[state]])
	get_tree().paused = (state == State.PAUSED)
	Engine.time_scale = 1.0
	state_changed.emit(previous_state, state)
	_transitioning = false
	return true


func _is_valid_transition(from: State, to: State) -> bool:
	match to:
		State.MENU:
			return from in [State.BOOT, State.RESULTS, State.GAME_OVER, State.PAUSED]
		State.SERVE:
			# Reiniciar é válido de qualquer estado (inclusive durante o chefe).
			return from != State.BOOT
		State.PLAYING:
			return from in [State.SERVE, State.PAUSED, State.BOSS_FIGHT]
		State.BALL_LOST:
			return from in [State.PLAYING, State.BOSS_FIGHT]
		State.BOSS_INTRO:
			return from in [State.PLAYING]
		State.BOSS_FIGHT:
			return from in [State.BOSS_INTRO, State.PAUSED, State.SERVE]
		State.PAUSED:
			return from in [State.PLAYING, State.BOSS_FIGHT, State.SERVE, State.BOSS_INTRO]
		State.GAME_OVER:
			return from in [State.BALL_LOST]
		State.RESULTS:
			return from in [State.PLAYING, State.BOSS_FIGHT, State.GAME_OVER]
	return false


func _log(msg: String) -> void:
	var line := "[%8.3f] %s" % [game_time, msg]
	transition_log.append(line)
	if transition_log.size() > MAX_TRANSITION_LOG:
		transition_log.pop_front()
	if debug_enabled or headless:
		print("GameManager: " + line)


func is_in_game() -> bool:
	return state in [State.SERVE, State.PLAYING, State.BOSS_FIGHT, State.BOSS_INTRO]


func is_ball_in_play() -> bool:
	return state in [State.PLAYING, State.BOSS_FIGHT]


# ---------------------------------------------------------------------------
# Fluxo da partida
# ---------------------------------------------------------------------------
func start_new_game(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) % 1_000_000_007
		if seed_value <= 0:
			seed_value = 1
	run_seed = seed_value
	rng.seed = run_seed
	SaveManager.last_seed = run_seed
	balls_left = STARTING_BALLS
	victory = false
	game_time = 0.0
	ScoreManager.reset()
	balls_changed.emit(balls_left)
	game_started.emit(run_seed)
	if state == State.PAUSED:
		get_tree().paused = false
	change_state(State.SERVE)


## Chamado pela mesa quando a bola sai do lançador e entra na mesa.
func on_ball_entered_play() -> void:
	if state == State.SERVE:
		# Se o chefe está despertado, voltamos direto para a luta.
		if table != null and table.has_method("is_boss_active") and table.is_boss_active():
			change_state(State.BOSS_FIGHT)
		else:
			change_state(State.PLAYING)


## Chamado pela mesa quando TODAS as bolas ativas drenaram sem ball save.
func on_all_balls_lost() -> void:
	if not (state == State.PLAYING or state == State.BOSS_FIGHT or state == State.SERVE):
		return
	if state == State.SERVE:
		# Bola drenou antes de entrar em jogo (raro): volta ao lançador sem punir.
		if table != null:
			table.call_deferred("serve_ball")
		return
	change_state(State.BALL_LOST)
	ScoreManager.on_ball_lost()
	balls_left -= 1
	balls_changed.emit(balls_left)
	if balls_left <= 0:
		change_state(State.GAME_OVER)
		_finish_game(false)
	else:
		# Pequena pausa dramática antes de servir novamente.
		var timer := get_tree().create_timer(1.2, false)
		timer.timeout.connect(func():
			if state == State.BALL_LOST:
				change_state(State.SERVE)
				if table != null:
					table.serve_ball()
		)


func on_boss_awakened() -> void:
	if state != State.PLAYING:
		return
	change_state(State.BOSS_INTRO)
	var timer := get_tree().create_timer(2.0, false)
	timer.timeout.connect(func():
		if state == State.BOSS_INTRO:
			change_state(State.BOSS_FIGHT)
	)


func on_boss_defeated_and_bonus_finished() -> void:
	if state in [State.PLAYING, State.BOSS_FIGHT]:
		victory = true
		change_state(State.RESULTS)
		_finish_game(true)


func _finish_game(won: bool) -> void:
	var is_record := SaveManager.submit_score(ScoreManager.score)
	game_ended.emit(won, ScoreManager.score, is_record)


func pause_game() -> void:
	if is_in_game():
		_resume_state = state
		change_state(State.PAUSED)


func resume_game() -> void:
	if state == State.PAUSED:
		change_state(_resume_state)


func restart_game() -> void:
	# Reinício válido de qualquer estado de jogo, inclusive durante o chefe.
	if state == State.PAUSED:
		get_tree().paused = false
	if table != null and table.has_method("reset_table"):
		table.reset_table()
	start_new_game()


func return_to_menu() -> void:
	if state == State.PAUSED:
		get_tree().paused = false
	if state in [State.PLAYING, State.BOSS_FIGHT, State.SERVE, State.BOSS_INTRO]:
		# Abandono conta como partida encerrada (sem vitória).
		_finish_game(false)
		state = State.GAME_OVER  # atalho controlado: não passa por BALL_LOST
		_log("abandono -> GAME_OVER")
	if table != null and table.has_method("reset_table"):
		table.reset_table()
	change_state(State.MENU)


# ---------------------------------------------------------------------------
# Input map em código (permite remapeamento futuro e evita depender do editor)
# ---------------------------------------------------------------------------
func _setup_input_map() -> void:
	_add_action("flipper_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_LEFT_SHOULDER])
	_add_action("flipper_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("plunger", [KEY_SPACE], [JOY_BUTTON_A])
	_add_action("nudge_left", [KEY_Q], [JOY_BUTTON_DPAD_LEFT])
	_add_action("nudge_right", [KEY_E], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("magic", [KEY_SHIFT], [JOY_BUTTON_X])
	_add_action("pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_add_action("debug_toggle", [KEY_F3], [])
	_add_action("ui_start", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A, JOY_BUTTON_START])


func _add_action(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
