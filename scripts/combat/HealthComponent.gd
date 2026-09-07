class_name HealthComponent
extends Node
## Componente de vida. Protege contra dano múltiplo da mesma sobreposição e dano após a morte.

signal damaged(amount: int, hit_position: Vector2, critical: bool)
signal died(points: int)
signal revived()

@export var max_hp: int = 3
@export var points_on_death: int = 1000
@export var invulnerability_ms: int = Combat.INVULN_MS

var hp: int
var is_dead := false
var _last_damage_msec: int = -100000
var _clock_msec: int = 0  # relógio próprio (físico) para determinismo em testes
var external_invulnerable := false


func _ready() -> void:
	hp = max_hp


func _physics_process(delta: float) -> void:
	_clock_msec += int(round(delta * 1000.0))


## Retorna o dano efetivamente aplicado (0 se ignorado).
func apply_damage(amount: int, hit_position: Vector2 = Vector2.ZERO, critical: bool = false) -> int:
	if is_dead or amount <= 0 or external_invulnerable:
		return 0
	if _clock_msec - _last_damage_msec < invulnerability_ms:
		return 0
	_last_damage_msec = _clock_msec
	hp = maxi(hp - amount, 0)
	damaged.emit(amount, hit_position, critical)
	if hp == 0:
		is_dead = true
		died.emit(points_on_death)
	return amount


func revive(new_max_hp: int = -1) -> void:
	if new_max_hp > 0:
		max_hp = new_max_hp
	hp = max_hp
	is_dead = false
	_last_damage_msec = -100000
	revived.emit()


func ratio() -> float:
	return float(hp) / float(maxi(max_hp, 1))
