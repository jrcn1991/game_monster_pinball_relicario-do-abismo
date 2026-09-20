extends Node
## ScoreManager: pontos, combo e multiplicador. Determinístico: sem dependência de tempo real
## além do relógio de partida (tick por physics_process), para permitir testes.

signal score_changed(score: int)
signal combo_changed(combo: int, seconds_left: float)
signal multiplier_changed(multiplier: int)

const COMBO_WINDOW := 2.5
const MAX_MULTIPLIER := 10
const BONUS_MULTIPLIER := 5  # durante a sequência bônus após o chefe

var score: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var multiplier: int = 1
var bonus_active: bool = false
var _last_target_id: String = ""
var _combo_targets: Dictionary = {}  # ids acertados na janela atual
var _multiplier_progress: int = 0  # acertos distintos acumulados para subir o multiplicador

const MULTIPLIER_STEP := 12  # acertos distintos por nível de multiplicador


func _physics_process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			_break_combo()
		else:
			combo_changed.emit(combo, combo_timer)


func reset() -> void:
	score = 0
	combo = 0
	combo_timer = 0.0
	multiplier = 1
	bonus_active = false
	_last_target_id = ""
	_combo_targets.clear()
	_multiplier_progress = 0
	score_changed.emit(score)
	combo_changed.emit(combo, 0.0)
	multiplier_changed.emit(multiplier)


## Registra um acerto em um alvo identificado. Retorna os pontos concedidos (já multiplicados).
func register_hit(target_id: String, base_points: int, position: Vector2 = Vector2.ZERO) -> int:
	# Combo cresce apenas com alvos DIFERENTES dentro da janela.
	if target_id != _last_target_id and not _combo_targets.has(target_id):
		combo += 1
		_combo_targets[target_id] = true
		_multiplier_progress += 1
		if _multiplier_progress >= MULTIPLIER_STEP and multiplier < MAX_MULTIPLIER:
			_multiplier_progress = 0
			multiplier += 1
			multiplier_changed.emit(multiplier)
	_last_target_id = target_id
	combo_timer = COMBO_WINDOW
	var points := compute_points(base_points)
	add_points(points)
	combo_changed.emit(combo, combo_timer)
	SignalBus.target_hit.emit(target_id, points, position)
	return points


func compute_points(base_points: int) -> int:
	var p := base_points * multiplier
	if bonus_active:
		p *= BONUS_MULTIPLIER
	# Bônus de combo: +5% por nível de combo até +100%.
	p = int(round(p * (1.0 + 0.05 * float(mini(combo, 20)))))
	return p


func add_multiplier(amount: int = 1) -> void:
	multiplier = clampi(multiplier + amount, 1, MAX_MULTIPLIER)
	multiplier_changed.emit(multiplier)


## Pontos diretos (sem interação com combo), já multiplicados pelo multiplicador atual.
func add_points_raw(base_points: int) -> int:
	var p := base_points * multiplier
	if bonus_active:
		p *= BONUS_MULTIPLIER
	add_points(p)
	return p


func add_points(points: int) -> void:
	score += points
	score_changed.emit(score)


## Bônus de combo usado no cálculo de dano (1.0 .. 1.5).
func combo_damage_bonus() -> float:
	return 1.0 + 0.05 * float(mini(combo, 10))


func _break_combo() -> void:
	combo = 0
	combo_timer = 0.0
	_last_target_id = ""
	_combo_targets.clear()
	combo_changed.emit(combo, 0.0)


func break_combo() -> void:
	_break_combo()


func on_ball_lost() -> void:
	_break_combo()
	# Perder a bola reduz um nível de multiplicador (mínimo 1). Consequência compreensível.
	if multiplier > 1:
		multiplier -= 1
		multiplier_changed.emit(multiplier)
	_multiplier_progress = 0


static func format_short(value: int) -> String:
	if value >= 1_000_000_000:
		return "%.2fB" % (value / 1_000_000_000.0)
	if value >= 1_000_000:
		return "%.2fM" % (value / 1_000_000.0)
	if value >= 10_000:
		return "%.1fK" % (value / 1_000.0)
	return str(value)


static func format_full(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out
