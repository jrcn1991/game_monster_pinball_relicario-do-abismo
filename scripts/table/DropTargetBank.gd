class_name DropTargetBank
extends Node2D
## Banco de drop targets. Quando todos caem: bônus, sinal e reset após um intervalo.

signal bank_completed()

@export var bonus_points: int = 3000
@export var reset_delay: float = 2.5

var targets: Array[DropTarget] = []
var completions := 0
var _resetting := false


func _ready() -> void:
	for c in get_children():
		if c is DropTarget:
			targets.append(c)
			c.dropped.connect(_on_dropped)


func _on_dropped(_t: DropTarget) -> void:
	if _resetting:
		return
	for t in targets:
		if not t.is_down:
			return
	_resetting = true
	completions += 1
	ScoreManager.add_points_raw(bonus_points)
	AudioManager.play_sfx("drop_bank_complete", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("drop_bank"), 2.0)
	bank_completed.emit()
	var timer := get_tree().create_timer(reset_delay, false)
	timer.timeout.connect(reset_bank)


func reset_bank() -> void:
	for t in targets:
		t.reset_target()
	_resetting = false


func all_down() -> bool:
	for t in targets:
		if not t.is_down:
			return false
	return true
