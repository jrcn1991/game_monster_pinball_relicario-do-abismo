class_name TableSystems
extends Node
## Regras de "mesa profunda" (lote A): Rosário (bônus persistente), multiplicador de bônus por
## Sinos, Voltas do Claustro, skill shot, Turíbulo/Oração Relâmpago/Indulgências, Sacristia
## (letras + prêmio aleatório) e Guardiões das outlanes.

signal bonus_changed(spins: int, relics: int, bonus_mult: int)
signal indulgences_changed(count: int)
signal prayer_changed(active: bool, seconds_left: float, value: int)
signal loops_changed(loops: int)
signal sacristy_changed(letters: int)

const MAX_BONUS_MULT := 12
const PRAYER_SECONDS := 10.0
const PRAYER_BASE := 25000
const LOOP_LIGHT_SECONDS := 8.0
const SACRISTY_LETTERS := "SACRIS"

var table: Node = null
var rng := RandomNumberGenerator.new()

# Rosário
var spins_total := 0
var spins_toward_milestone := 0
var milestone_index := 0
const MILESTONES := [15, 30, 60, 90, 119]
var bonus_mult := 1
var relics := 0
var hold_bonus_mult := false

# Oração Relâmpago / Indulgências
var prayer_active := false
var prayer_left := 0.0
var prayer_value := PRAYER_BASE
var prayer_rounds := 0
var indulgences := 0
var indulgence_lit := false

# Voltas do Claustro
var loop_lit_left := false
var loop_lit_right := false
var loop_timer := 0.0
var loops := 0
var loops_total := 0
var extra_balls_from_loops := 0

# Skill shot
var skill_lane := -1
var skill_window := 0.0
var skill_shots := 0

# Sacristia
var sacristy_letters := 0
var sacristy_step := 3
var sacristy_awards := 0
var last_award := ""

# Cativas -> Fogo-Fátuo (lote B)
var captive_hits_lit := 0


func setup(t: Node) -> void:
	table = t
	rng.seed = GameManager.run_seed + 777
	GameManager.balls_changed.connect(func(_n): pass)


func reset_game() -> void:
	spins_total = 0
	spins_toward_milestone = 0
	milestone_index = 0
	bonus_mult = 1
	relics = 0
	hold_bonus_mult = false
	prayer_active = false
	prayer_left = 0.0
	prayer_value = PRAYER_BASE
	prayer_rounds = 0
	indulgences = 0
	indulgence_lit = false
	loop_lit_left = false
	loop_lit_right = false
	loops = 0
	loops_total = 0
	extra_balls_from_loops = 0
	skill_lane = -1
	sacristy_letters = 0
	sacristy_step = 3
	sacristy_awards = 0
	captive_hits_lit = 0
	_emit_all()


## Chamado ao servir uma bola nova (não em bola salva): zera o que zera por bola.
func on_new_ball() -> void:
	if not hold_bonus_mult:
		bonus_mult = 1
	hold_bonus_mult = false
	loops = 0
	loop_lit_left = false
	loop_lit_right = false
	skill_lane = rng.randi_range(0, 2)
	skill_window = 0.0
	if table != null and table.top_lanes != null:
		for i in table.top_lanes.rollovers.size():
			table.top_lanes.rollovers[i].set_lit(false)
			table.top_lanes.rollovers[i].modulate = Color(1.3, 1.2, 0.8) if i == skill_lane else Color.WHITE
	_emit_all()


func on_ball_launched() -> void:
	skill_window = 4.0


func _physics_process(delta: float) -> void:
	if prayer_active:
		prayer_left -= delta
		prayer_changed.emit(true, prayer_left, prayer_value)
		if prayer_left <= 0.0:
			_end_prayer()
	if loop_timer > 0.0:
		loop_timer -= delta
		if loop_timer <= 0.0:
			loop_lit_left = false
			loop_lit_right = false
			loops = 0
			loops_changed.emit(loops)
	if skill_window > 0.0:
		skill_window -= delta


func _emit_all() -> void:
	bonus_changed.emit(spins_total, relics, bonus_mult)
	indulgences_changed.emit(indulgences)
	prayer_changed.emit(prayer_active, prayer_left, prayer_value)
	loops_changed.emit(loops)
	sacristy_changed.emit(sacristy_letters)


# ---------------------------------------------------------------------------------
# Turíbulo
# ---------------------------------------------------------------------------------
func on_censer_spin(half_turns: int) -> void:
	for i in half_turns:
		spins_total = mini(spins_total + 1, 999)
		if prayer_active:
			prayer_left = PRAYER_SECONDS
			var v := ScoreManager.add_points_raw(prayer_value / maxi(ScoreManager.multiplier, 1))
			prayer_value += 5000
			SignalBus.hud_message.emit("%s +%s" % [Loc.t("prayer"), ScoreManager.format_short(v)], 0.8)
		else:
			spins_toward_milestone += 1
			if milestone_index < MILESTONES.size() and spins_total >= MILESTONES[milestone_index]:
				milestone_index += 1
				_start_prayer()
	bonus_changed.emit(spins_total, relics, bonus_mult)


func _start_prayer() -> void:
	prayer_active = true
	prayer_left = PRAYER_SECONDS
	prayer_value = PRAYER_BASE
	prayer_rounds += 1
	AudioManager.play_sfx("magic_on", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("prayer"), 2.0)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.4)
	prayer_changed.emit(true, prayer_left, prayer_value)


func _end_prayer() -> void:
	prayer_active = false
	prayer_left = 0.0
	prayer_changed.emit(false, 0.0, prayer_value)
	grant_indulgence()


func grant_indulgence() -> void:
	if indulgences < 3:
		indulgences += 1
	indulgence_lit = true
	indulgences_changed.emit(indulgences)
	SignalBus.hud_message.emit(Loc.t("indulgence_ready"), 2.0)
	AudioManager.play_sfx("portal_open", 0.0, -6.0)


# ---------------------------------------------------------------------------------
# Sinos (cativas) -> multiplicador de bônus
# ---------------------------------------------------------------------------------
func on_captive_hit(captive: Node, strong: bool) -> void:
	if strong and captive.lit:
		bonus_mult = mini(bonus_mult + 1, MAX_BONUS_MULT)
		captive_hits_lit += 1
		SignalBus.hud_message.emit(Loc.t("captive") % bonus_mult, 1.0)
		bonus_changed.emit(spins_total, relics, bonus_mult)


# ---------------------------------------------------------------------------------
# Voltas do Claustro
# ---------------------------------------------------------------------------------
func on_inlane(side: int) -> void:
	# inlane esquerda acende a órbita direita e vice-versa
	if side == 0:
		loop_lit_right = true
	else:
		loop_lit_left = true
	loop_timer = LOOP_LIGHT_SECONDS


func on_orbit_made(side: int) -> void:
	var lit := loop_lit_left if side == 0 else loop_lit_right
	ScoreManager.register_hit("orbit_%d" % side, 1500, Vector2.ZERO)
	if lit:
		loops += 1
		loops_total += 1
		loop_timer = LOOP_LIGHT_SECONDS
		# A volta acende a órbita oposta para encadear.
		loop_lit_left = side == 1
		loop_lit_right = side == 0
		ScoreManager.add_points_raw(2000 * loops)
		SignalBus.hud_message.emit("%s %d" % [Loc.t("loop"), loops], 1.0)
		loops_changed.emit(loops)
		if loops_total == 6 or loops_total == 20:
			award_extra_ball()


func award_extra_ball() -> void:
	GameManager.balls_left = mini(GameManager.balls_left + 1, 9)
	GameManager.balls_changed.emit(GameManager.balls_left)
	extra_balls_from_loops += 1
	AudioManager.play_sfx("victory", 0.0, -4.0)
	SignalBus.hud_message.emit(Loc.t("extra_ball"), 2.5)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.6)


# ---------------------------------------------------------------------------------
# Skill shot (lanes do topo)
# ---------------------------------------------------------------------------------
func on_top_lane(index: int) -> void:
	if skill_window > 0.0 and index == skill_lane:
		skill_window = 0.0
		skill_shots += 1
		var v := ScoreManager.add_points_raw(10000 * (1 + index))
		SignalBus.hud_message.emit("%s +%s" % [Loc.t("skill_shot"), ScoreManager.format_short(v)], 1.5)
		AudioManager.play_sfx("jackpot", 0.0, -4.0)
		skill_lane = -1
	elif skill_window > 0.0:
		skill_window = 0.0


# ---------------------------------------------------------------------------------
# Sacristia (scoop): letras e prêmio aleatório
# ---------------------------------------------------------------------------------
func on_sacristy_letter_source() -> String:
	if sacristy_letters >= SACRISTY_LETTERS.length():
		return ""
	sacristy_letters = mini(sacristy_letters + sacristy_step, SACRISTY_LETTERS.length())
	sacristy_changed.emit(sacristy_letters)
	if sacristy_letters >= SACRISTY_LETTERS.length():
		return "complete"
	return SACRISTY_LETTERS.substr(0, sacristy_letters)


## Prêmio da Sacristia quando as 6 letras estão completas. Retorna o texto do prêmio.
func sacristy_award() -> String:
	sacristy_letters = 0
	sacristy_step = maxi(sacristy_step - 1, 1)
	sacristy_awards += 1
	sacristy_changed.emit(0)
	var roll := rng.randf()
	var text := ""
	if roll < 0.04 and GameManager.balls_left < 5:
		award_extra_ball()
		text = Loc.t("extra_ball")
	elif roll < 0.20:
		bonus_mult = mini(bonus_mult + 3, MAX_BONUS_MULT)
		text = "BÔNUS +3 (x%d)" % bonus_mult
		bonus_changed.emit(spins_total, relics, bonus_mult)
	elif roll < 0.35:
		on_censer_spin(15)
		text = "+15 SOPROS"
	elif roll < 0.55:
		var v := ScoreManager.add_points_raw(25000)
		text = "+%s" % ScoreManager.format_short(v)
	elif roll < 0.65:
		var v2 := ScoreManager.add_points_raw(50000)
		text = "+%s" % ScoreManager.format_short(v2)
	elif roll < 0.75:
		hold_bonus_mult = true
		text = "SEGURAR BÔNUS x%d" % bonus_mult
	elif roll < 0.85:
		if table != null and table.locked_balls < 2:
			table.locked_balls = 2
			SignalBus.ball_locked.emit(2)
			text = "TRAVAS ACESAS"
		else:
			var v3 := ScoreManager.add_points_raw(20000)
			text = "+%s" % ScoreManager.format_short(v3)
	elif roll < 0.93:
		grant_indulgence()
		text = "INDULGÊNCIA"
	else:
		if table != null:
			table.add_mana(100)
		text = "MANA CHEIA"
	last_award = text
	return text


# ---------------------------------------------------------------------------------
# Bônus de fim de bola (Rosário)
# ---------------------------------------------------------------------------------
func compute_end_bonus() -> int:
	return (1000 * spins_total + 5000 * relics) * bonus_mult


func collect_end_bonus() -> int:
	var b := compute_end_bonus()
	if b > 0:
		ScoreManager.add_points(b)
		SignalBus.hud_message.emit(Loc.t("end_bonus") % [str(spins_total), relics, bonus_mult, ScoreManager.format_short(b)], 2.4)
		AudioManager.play_sfx("drop_bank_complete", 0.0, 0.0)
	return b


func add_relic() -> void:
	relics += 1
	bonus_changed.emit(spins_total, relics, bonus_mult)
