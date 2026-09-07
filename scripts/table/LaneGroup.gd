class_name LaneGroup
extends Node2D
## Grupo de rollovers "ELOS" (a corrente). Completar tudo ativa ball save por 8 segundos.

signal completed()

@export var completion_points: int = 5000

var rollovers: Array[Rollover] = []
var completions := 0


func _ready() -> void:
	for c in get_children():
		if c is Rollover:
			rollovers.append(c)
			c.rolled.connect(_on_rolled)


func _on_rolled(_r: Rollover) -> void:
	for r in rollovers:
		if not r.lit:
			return
	completions += 1
	ScoreManager.add_points_raw(completion_points)
	AudioManager.play_sfx("ball_save", 0.0, 0.0)
	SignalBus.hud_message.emit(Loc.t("lanes_complete"), 2.0)
	for r in rollovers:
		r.set_lit(false)
	completed.emit()


func reset_lanes() -> void:
	for r in rollovers:
		r.set_lit(false)
