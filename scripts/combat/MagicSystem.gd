class_name MagicSystem
extends Node
## Mana e a habilidade Bola Consagrada (custo 100, dura 8 s, 2× dano, atravessa projéteis,
## onda de dano pequena sem empurrar a bola). Não acumula: reativar apenas renova até 8 s.

signal mana_changed(current: int, maximum: int)
signal magic_started(seconds: float)
signal magic_ended()

const MAX_MANA := 100
const COST := 100
const DURATION := 8.0
const SHOCKWAVE_RADIUS := 90.0

var mana: int = 0
var time_left := 0.0
var active := false
var table: Node = null  # GameTable (fornece active_balls e enemies)
var casts := 0


func _physics_process(delta: float) -> void:
	if active:
		time_left -= delta
		if time_left <= 0.0:
			_end()


func reset() -> void:
	mana = 0
	if active:
		_end()
	mana_changed.emit(mana, MAX_MANA)
	SignalBus.mana_changed.emit(mana, MAX_MANA)


func add_mana(amount: int) -> void:
	var before := mana
	mana = clampi(mana + amount, 0, MAX_MANA)
	if mana != before:
		mana_changed.emit(mana, MAX_MANA)
		SignalBus.mana_changed.emit(mana, MAX_MANA)
		if mana >= COST and before < COST:
			SignalBus.hud_message.emit(Loc.t("magic_ready"), 2.0)


func can_cast() -> bool:
	return mana >= COST


## Retorna true se ativou/renovou.
func try_cast() -> bool:
	if not can_cast():
		return false
	mana -= COST
	casts += 1
	mana_changed.emit(mana, MAX_MANA)
	SignalBus.mana_changed.emit(mana, MAX_MANA)
	time_left = DURATION  # renova, nunca acumula além do limite
	if not active:
		active = true
		_apply_to_balls(true)
		magic_started.emit(DURATION)
		SignalBus.magic_activated.emit(DURATION)
	AudioManager.play_sfx("magic_on", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("magic_on"), 1.5)
	SignalBus.request_flash.emit(Color(0.96, 0.83, 0.37), 0.35)
	return true


func _end() -> void:
	active = false
	time_left = 0.0
	_apply_to_balls(false)
	magic_ended.emit()
	SignalBus.magic_ended.emit()
	AudioManager.play_sfx("magic_off", 0.0, -4.0)


func _apply_to_balls(value: bool) -> void:
	if table == null:
		return
	for b in table.get_active_balls():
		if is_instance_valid(b):
			b.set_consecrated(value)


## Chamado por uma bola recém-criada durante a magia.
func apply_to_new_ball(ball: Ball) -> void:
	ball.set_consecrated(active)


## Onda de dano ao redor de um impacto consagrado: 1 de dano a inimigos próximos, sem empurrar.
func shockwave(origin: Vector2, exclude: Node) -> void:
	if not active or table == null:
		return
	for e in table.get_enemies():
		if e == exclude or not is_instance_valid(e) or not e.has_method("take_area_damage"):
			continue
		if e.global_position.distance_to(origin) <= SHOCKWAVE_RADIUS:
			e.take_area_damage(1, origin)
