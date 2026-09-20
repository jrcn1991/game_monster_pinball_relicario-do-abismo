class_name ChapterSystem
extends Node
## Lote B: os 7 Capítulos do Relicário (modos com progresso persistente), Relíquias na rampa,
## Indulgência (escolha no scoop), Fogo-Fátuo (hurry-up), Frenesi das Catacumbas (2 bolas)
## e melhorias do Multiball do Abismo (jackpot crescente, reacender, Revanche).

signal chapter_changed(index: int, name: String, progress_text: String, active: bool)
signal relics_changed(mask: int, count: int)
signal hurryup_changed(active: bool, value: int, seconds_left: float)
signal frenzy_changed(active: bool, jackpot: int)
signal choice_changed(active: bool, left_text: String, right_text: String, seconds_left: float)
signal all_relics_collected()

const SHOTS := ["bank_left", "orbit_left", "ramp", "orbit_right", "bank_right"]
const CHAPTERS := [
	{"id": "gargulas", "name": "Gárgulas", "desc": "Acerte 3 sinos (bumpers)"},
	{"id": "litania", "name": "Litania", "desc": "Soletre 6 letras nos bancos de alvos"},
	{"id": "sepulcros", "name": "Sepulcros", "desc": "Quebre os vitrais até achar a relíquia oculta"},
	{"id": "sussurro", "name": "Sussurro", "desc": "Acerte qualquer vitral"},
	{"id": "procissao", "name": "Procissão", "desc": "5 acertos em qualquer vitral"},
	{"id": "ascensao", "name": "Ascensão", "desc": "Complete a rampa"},
	{"id": "behemoth", "name": "Behemoth", "desc": "Acerte um sino cativo ou a sacristia"},
]
const HURRYUP_SECONDS := 20.0
const CHOICE_SECONDS := 8.0

var table: Node = null
var systems: Node = null
var rng := RandomNumberGenerator.new()

var selected := 0
var active := -1
var progress: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var completed: Array[bool] = [false, false, false, false, false, false, false]
var relic_mask := 0
var relic_lit := false  # rampa acesa para coletar
var sepulcro_hidden := 4
var sepulcro_broken := 0

# Fogo-Fátuo
var fatuo_needed := 1
var fatuo_lit := false
var hurryup_active := false
var hurryup_value := 0
var hurryup_left := 0.0
var hurryups_collected := 0

# Frenesi
var frenzy_progress := 0
var frenzy_active := false
var frenzy_jackpot := 1000
var frenzy_bumper_bonus := 0
var frenzies := 0

# Multiball do Abismo
var abyss_jackpot_lit := false
var abyss_jackpot_value := 15000
var abyss_jackpots := 0
var abyss_relight_side := -1
var revanche_lit := false
var revanche_left := 0.0

# Indulgência (escolha)
var choice_active := false
var choice_left := 0.0
var _choice_scoop: Node = null
var relics_total := 0
var exorcism: Node = null


func setup(t: Node, sy: Node) -> void:
	table = t
	systems = sy
	rng.seed = GameManager.run_seed + 4321
	SignalBus.target_hit.connect(_on_any_target_hit)
	SignalBus.multiball_started.connect(_on_multiball_started)
	SignalBus.multiball_ended.connect(_on_multiball_ended)
	reset_game()


func reset_game() -> void:
	selected = 0
	active = -1
	for i in 7:
		progress[i] = 0
		completed[i] = false
	relic_mask = 0
	relic_lit = false
	relics_total = 0
	sepulcro_hidden = rng.randi_range(2, 4)
	sepulcro_broken = 0
	fatuo_needed = 1
	fatuo_lit = false
	hurryup_active = false
	hurryup_value = 0
	hurryup_left = 0.0
	frenzy_progress = 0
	frenzy_active = false
	frenzy_jackpot = 10000
	frenzy_bumper_bonus = 0
	abyss_jackpot_lit = false
	abyss_jackpot_value = 100000
	abyss_relight_side = -1
	revanche_lit = false
	choice_active = false
	_emit_chapter()
	relics_changed.emit(relic_mask, relics_total)
	hurryup_changed.emit(false, 0, 0.0)
	frenzy_changed.emit(false, frenzy_jackpot)
	choice_changed.emit(false, "", "", 0.0)


func _physics_process(delta: float) -> void:
	if hurryup_active:
		hurryup_left -= delta
		hurryup_value = maxi(hurryup_value - int(delta * (hurryup_value + 2000) / maxf(hurryup_left + 1.0, 1.0)), 5000)
		hurryup_changed.emit(true, hurryup_value, hurryup_left)
		if hurryup_left <= 0.0:
			hurryup_active = false
			hurryup_changed.emit(false, 0, 0.0)
			SignalBus.hud_message.emit("FOGO-FÁTUO APAGOU", 1.5)
	if revanche_lit:
		revanche_left -= delta
		if revanche_left <= 0.0:
			revanche_lit = false
	if choice_active:
		choice_left -= delta
		choice_changed.emit(true, _choice_left_text(), _choice_right_text(), choice_left)
		if choice_left <= 0.0:
			_resolve_choice(false)


func _unhandled_input(event: InputEvent) -> void:
	if choice_active:
		if event.is_action_pressed("flipper_left"):
			_resolve_choice(true)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("flipper_right"):
			_resolve_choice(false)
			get_viewport().set_input_as_handled()
		return
	# Seleção de capítulo com o flipper esquerdo enquanto a bola está no lançador.
	if event.is_action_pressed("flipper_left") and active < 0 and table != null and table.plunger != null and table.plunger.has_ball():
		cycle_selection()


# ---------------------------------------------------------------------------------
# Seleção / início / conclusão
# ---------------------------------------------------------------------------------
func cycle_selection() -> void:
	if all_completed():
		return
	for i in 7:
		selected = (selected + 1) % 7
		if not completed[selected]:
			break
	AudioManager.play_sfx("ui_move", 0.1, -6.0)
	_emit_chapter()


func all_completed() -> bool:
	for c in completed:
		if not c:
			return false
	return true


func _first_incomplete() -> int:
	for i in 7:
		if not completed[i]:
			return i
	return -1


## Acerto no Guardião (corpo): inicia o capítulo selecionado (se nenhum ativo).
func on_guardian_body_hit() -> void:
	if exorcism != null and exorcism.lit and not exorcism.is_active():
		exorcism.start()
		return
	if active < 0 and not completed[selected] and not relic_lit:
		start_chapter(selected)


## Derrota no Exorcismo: as relíquias precisam ser coletadas de novo.
func reset_relics() -> void:
	relic_mask = 0
	relics_total = 0
	for i in 7:
		completed[i] = false
		progress[i] = 0
	active = -1
	relic_lit = false
	selected = 0
	relics_changed.emit(relic_mask, relics_total)
	_emit_chapter()


func start_chapter(index: int) -> void:
	if index < 0 or completed[index]:
		return
	active = index
	if index == 2 and sepulcro_broken == 0:
		sepulcro_hidden = rng.randi_range(2, 4)
	AudioManager.play_sfx("portal_open", 0.0, -4.0)
	SignalBus.hud_message.emit("CAPÍTULO: %s" % (CHAPTERS[index].name as String).to_upper(), 2.0)
	SignalBus.request_flash.emit(Color(0.78, 0.49, 1.0), 0.3)
	_emit_chapter()


func _complete_active() -> void:
	if active < 0:
		return
	completed[active] = true
	relic_lit = true
	AudioManager.play_sfx("drop_bank_complete", 0.0, 0.0)
	SignalBus.hud_message.emit("CAPÍTULO CONCLUÍDO: RAMPA ACESA (RELÍQUIA)", 2.5)
	ScoreManager.add_points_raw(10000)
	active = -1
	_emit_chapter()


## Rampa completada: coleta a relíquia se acesa.
func on_ramp_completed() -> void:
	_shot("ramp")
	if relic_lit:
		_collect_relic(1)
	if fatuo_lit and not hurryup_active:
		_start_hurryup()
	elif hurryup_active:
		hurryup_value = mini(hurryup_value + 20000, 40000 + 20000 * fatuo_needed)


func _collect_relic(count: int) -> void:
	relic_lit = false
	for i in count:
		var idx := _next_relic_index()
		if idx < 0:
			break
		relic_mask |= 1 << idx
		relics_total += 1
		systems.add_relic()
	ScoreManager.add_points_raw(10000 * count)
	AudioManager.play_sfx("jackpot", 0.0, 0.0)
	SignalBus.hud_message.emit("RELÍQUIA COLETADA (%d/7)" % relics_total, 2.5)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.5)
	relics_changed.emit(relic_mask, relics_total)
	if relics_total == 4:
		systems.award_extra_ball()
	# Próximo capítulo incompleto fica selecionado.
	var nxt := _first_incomplete()
	if nxt >= 0:
		selected = nxt
	_emit_chapter()
	if relics_total >= 7:
		all_relics_collected.emit()


func _next_relic_index() -> int:
	for i in 7:
		if relic_mask & (1 << i) == 0:
			return i
	return -1


# ---------------------------------------------------------------------------------
# Eventos de tiro
# ---------------------------------------------------------------------------------
func _shot(shot_id: String) -> void:
	if exorcism != null and exorcism.is_active() and shot_id in SHOTS:
		exorcism.on_vitral(shot_id)
		return
	if active < 0:
		return
	var id: String = CHAPTERS[active].id
	match id:
		"sepulcros":
			var si := SHOTS.find(shot_id)
			if si >= 0:
				sepulcro_broken += 1
				progress[active] = sepulcro_broken
				ScoreManager.add_points_raw(3000)
				if sepulcro_broken >= sepulcro_hidden + 1:
					SignalBus.hud_message.emit("A RELÍQUIA OCULTA!", 1.5)
					_complete_active()
				else:
					SignalBus.hud_message.emit("VITRAL QUEBRADO (%d)" % sepulcro_broken, 1.0)
		"sussurro":
			if shot_id in SHOTS:
				progress[active] += 1
				ScoreManager.add_points_raw(5000)
				_complete_active()
		"procissao":
			if shot_id in SHOTS:
				progress[active] += 1
				ScoreManager.add_points_raw(4000)
				SignalBus.hud_message.emit("PROCISSÃO %d/5" % progress[active], 1.0)
				if progress[active] >= 5:
					_complete_active()
		"ascensao":
			if shot_id == "ramp":
				progress[active] += 1
				ScoreManager.add_points_raw(8000)
				_complete_active()
		"litania":
			if shot_id == "bank_left" or shot_id == "bank_right":
				progress[active] += 1
				ScoreManager.add_points_raw(3000)
				SignalBus.hud_message.emit("LITANIA: %s" % "LITANIA".substr(0, mini(progress[active], 7)), 1.0)
				if progress[active] >= 6:
					_complete_active()
	_emit_chapter()


func on_bank_left_hit() -> void:
	_shot("bank_left")


func on_bank_right_hit() -> void:
	_shot("bank_right")


func on_orbit(side: int) -> void:
	_shot("orbit_left" if side == 0 else "orbit_right")
	if side == 0 and not frenzy_active:
		frenzy_progress += 1
		if frenzy_progress >= 5:
			frenzy_progress = 0
			_start_frenzy()
		else:
			SignalBus.hud_message.emit("CATACUMBAS %d/5" % frenzy_progress, 0.8)
	# Multiball: reacende o jackpot na órbita sorteada.
	if table != null and table.multiball_active and abyss_relight_side == side:
		abyss_relight_side = -1
		abyss_jackpot_lit = true
		SignalBus.hud_message.emit("JACKPOT REACESO NO GUARDIÃO", 1.5)


func on_bumper_hit() -> void:
	if active >= 0 and CHAPTERS[active].id == "gargulas":
		progress[active] += 1
		ScoreManager.add_points_raw(2000)
		if progress[active] >= 3:
			_complete_active()
		_emit_chapter()
	if frenzy_active:
		frenzy_bumper_bonus += 100
		frenzy_jackpot += 100
		frenzy_changed.emit(true, frenzy_jackpot)


func on_captive_hit() -> void:
	if active >= 0 and CHAPTERS[active].id == "behemoth":
		progress[active] += 1
		ScoreManager.add_points_raw(3000 + 3000 * progress[active])
		_complete_active()
		_emit_chapter()
	if not fatuo_lit:
		systems.captive_hits_lit += 0  # contagem já feita pelo TableSystems
		if systems.captive_hits_lit >= fatuo_needed:
			fatuo_lit = true
			SignalBus.hud_message.emit("FOGO-FÁTUO ACESO NA RAMPA", 1.5)


## Scoop: Indulgência (se acesa) ou Revanche (multiball) ou Behemoth; retorna true se a bola
## deve ficar presa para a escolha.
func on_scoop(scoop: Node) -> bool:
	if active >= 0 and CHAPTERS[active].id == "behemoth":
		progress[active] += 1
		ScoreManager.add_points_raw(10000)
		_complete_active()
	if revanche_lit and table != null:
		revanche_lit = false
		SignalBus.hud_message.emit("REVANCHE!", 1.5)
		table.call_deferred("spawn_ball_at", table.LOCK_POS + Vector2(30, 10), Vector2(200.0, 650.0))
		table.multiball_active = true
		return false
	if systems.indulgence_lit and systems.indulgences > 0 and not table.multiball_active:
		_begin_choice(scoop)
		return true
	return false


# ---------------------------------------------------------------------------------
# Guardião: jackpot do multiball / coleta do Fogo-Fátuo
# ---------------------------------------------------------------------------------
func on_guardian_body_hit_full() -> void:
	if hurryup_active:
		hurryup_active = false
		hurryups_collected += 1
		fatuo_needed += 1
		fatuo_lit = false
		systems.captive_hits_lit = 0
		var v := ScoreManager.add_points_raw(hurryup_value / maxi(ScoreManager.multiplier, 1))
		hurryup_changed.emit(false, 0, 0.0)
		AudioManager.play_sfx("jackpot", 0.0, 0.0)
		SignalBus.hud_message.emit("FOGO-FÁTUO COLETADO +%s" % ScoreManager.format_short(v), 2.0)
		return
	if table != null and table.multiball_active and abyss_jackpot_lit:
		abyss_jackpot_lit = false
		abyss_jackpots += 1
		var v2 := ScoreManager.add_points_raw(abyss_jackpot_value / maxi(ScoreManager.multiplier, 1))
		abyss_relight_side = rng.randi_range(0, 1)
		AudioManager.play_sfx("jackpot", 0.0, 0.0)
		SignalBus.hud_message.emit("JACKPOT +%s · REACENDA NA ÓRBITA %s" % [ScoreManager.format_short(v2), "ESQUERDA" if abyss_relight_side == 0 else "DIREITA"], 2.5)
		SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.5)
		return
	on_guardian_body_hit()


func _start_hurryup() -> void:
	hurryup_active = true
	hurryup_left = HURRYUP_SECONDS
	hurryup_value = 40000 + 20000 * (fatuo_needed - 1)
	AudioManager.play_sfx("boss_phase", 0.0, -4.0)
	SignalBus.hud_message.emit("FOGO-FÁTUO! ACERTE O GUARDIÃO", 2.0)
	hurryup_changed.emit(true, hurryup_value, hurryup_left)


# ---------------------------------------------------------------------------------
# Multiball do Abismo
# ---------------------------------------------------------------------------------
func _on_multiball_started(_n: int) -> void:
	abyss_jackpot_lit = true
	abyss_jackpots = 0
	abyss_jackpot_value = 15000 + 300 * int(systems.spins_total)
	abyss_relight_side = -1
	SignalBus.hud_message.emit("JACKPOT ACESO NO GUARDIÃO", 2.0)


func _on_multiball_ended() -> void:
	if frenzy_active:
		_end_frenzy()
	if abyss_jackpots == 0 and table != null and GameManager.is_ball_in_play():
		revanche_lit = true
		revanche_left = 8.0
		SignalBus.hud_message.emit("REVANCHE NA SACRISTIA (8 s)", 2.0)


# ---------------------------------------------------------------------------------
# Frenesi das Catacumbas (2 bolas)
# ---------------------------------------------------------------------------------
func _start_frenzy() -> void:
	if table == null or frenzy_active:
		return
	frenzy_active = true
	frenzies += 1
	frenzy_jackpot = 1000 + frenzy_bumper_bonus
	table.spawn_ball_at(table.LOCK_POS + Vector2(30, 10), Vector2(200.0, 650.0))
	table.multiball_active = true
	table.ball_save_left = maxf(table.ball_save_left, 6.0)
	AudioManager.play_sfx("multiball_start", 0.0, 0.0)
	SignalBus.hud_message.emit("FRENESI DAS CATACUMBAS!", 2.5)
	SignalBus.request_flash.emit(Color(0.9, 0.22, 0.27), 0.5)
	frenzy_changed.emit(true, frenzy_jackpot)


func _end_frenzy() -> void:
	frenzy_active = false
	frenzy_changed.emit(false, frenzy_jackpot)
	SignalBus.hud_message.emit("FIM DO FRENESI", 1.5)


func _on_any_target_hit(_id: String, _points: int, _pos: Vector2) -> void:
	if frenzy_active:
		ScoreManager.add_points(frenzy_jackpot)


# ---------------------------------------------------------------------------------
# Indulgência
# ---------------------------------------------------------------------------------
func _choice_left_text() -> String:
	if all_completed():
		return "EXORCISMO FINAL"
	var idx := active if active >= 0 else selected
	return "RELÍQUIA: %s" % (CHAPTERS[idx].name as String).to_upper()


func _choice_right_text() -> String:
	if hurryup_active:
		return "3× FOGO-FÁTUO"
	if systems.prayer_active:
		return "3× ORAÇÃO"
	if not systems.prayer_active and systems.prayer_rounds == 0:
		return "ORAÇÃO RELÂMPAGO"
	if systems.loops_total < 6:
		return "+3 VOLTAS"
	return "COLETAR BÔNUS"


func _begin_choice(scoop: Node) -> void:
	choice_active = true
	choice_left = CHOICE_SECONDS
	_choice_scoop = scoop
	scoop.hold_indefinitely()
	AudioManager.play_sfx("magic_on", 0.0, -2.0)
	choice_changed.emit(true, _choice_left_text(), _choice_right_text(), choice_left)


func _resolve_choice(left: bool) -> void:
	if not choice_active:
		return
	choice_active = false
	systems.indulgences = maxi(systems.indulgences - 1, 0)
	systems.indulgence_lit = systems.indulgences > 0
	systems.indulgences_changed.emit(systems.indulgences)
	if left:
		if all_completed():
			if exorcism != null and not exorcism.is_active():
				exorcism.start()
		else:
			var idx := active if active >= 0 else selected
			active = idx
			completed[idx] = true
			active = -1
			relic_lit = false
			_collect_relic(1)
			SignalBus.hud_message.emit("INDULGÊNCIA: RELÍQUIA CONCEDIDA", 2.0)
	else:
		var txt := _choice_right_text()
		match txt:
			"3× FOGO-FÁTUO":
				hurryup_value *= 3
			"3× ORAÇÃO":
				systems.prayer_value *= 3
			"ORAÇÃO RELÂMPAGO":
				systems._start_prayer()
			"+3 VOLTAS":
				for i in 3:
					systems.loops_total += 1
					if systems.loops_total == 6 or systems.loops_total == 20:
						systems.award_extra_ball()
			_:
				var b: int = systems.collect_end_bonus()
				if b == 0:
					ScoreManager.add_points_raw(20000)
		SignalBus.hud_message.emit("INDULGÊNCIA: %s" % txt, 2.0)
	choice_changed.emit(false, "", "", 0.0)
	if _choice_scoop != null and is_instance_valid(_choice_scoop):
		_choice_scoop.release()
	_choice_scoop = null
	_emit_chapter()


# ---------------------------------------------------------------------------------
func _emit_chapter() -> void:
	var idx := active if active >= 0 else selected
	var name: String = CHAPTERS[idx].name
	var txt: String = CHAPTERS[idx].desc
	if active >= 0:
		txt = "%s (%d)" % [CHAPTERS[idx].desc, progress[idx]]
	elif relic_lit:
		txt = "Rampa acesa: colete a relíquia"
	elif completed[idx]:
		txt = "Concluído"
	else:
		txt = "Acerte o Guardião para iniciar · A/← troca"
	chapter_changed.emit(idx, name, txt, active >= 0)
