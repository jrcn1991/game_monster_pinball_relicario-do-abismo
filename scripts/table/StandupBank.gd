class_name StandupBank
extends Node2D
## Banco de stand-ups: agrupa alvos; "Vitral" de um lado da mesa.

signal any_hit(bank: StandupBank, target: StandupTarget)
signal bank_completed(bank: StandupBank)

@export var bank_id: String = "bank_right"

var targets: Array[StandupTarget] = []
var _hit_flags: Dictionary = {}


func _ready() -> void:
	for c in get_children():
		if c is StandupTarget:
			targets.append(c)
			c.target_hit.connect(_on_hit)


func _on_hit(t: StandupTarget, _speed: float) -> void:
	_hit_flags[t.get_instance_id()] = true
	any_hit.emit(self, t)
	if _hit_flags.size() >= targets.size():
		_hit_flags.clear()
		ScoreManager.add_points_raw(1500)
		bank_completed.emit(self)


func set_all_lit(value: bool) -> void:
	for t in targets:
		t.set_lit(value)


func reset_bank() -> void:
	_hit_flags.clear()
	set_all_lit(false)
