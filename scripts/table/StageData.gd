class_name StageData
extends Resource
## Dados de uma fase (mesa): arte, nomes, dificuldade. A geometria da mesa é compartilhada.

@export var id: String = "stage1"
@export var display_name: String = "Catedral Profanada"
@export var subtitle: String = "A bola é a arma"
@export var boss_name: String = "Bispo Sem-Rosto"
@export var art_dir: String = "res://assets/art/stages/stage1"
@export var music: String = "ambient_loop"
@export var boss_music: String = "boss_loop"
@export var enemy_hp_scale: float = 1.0
@export var boss_phase_hp: int = 20
@export var projectile_interval_scale: float = 1.0
@export var flyer_speed: float = 130.0
@export var skeleton_attack_scale: float = 1.0
@export var tint: Color = Color(1, 1, 1)


func tex(name: String) -> Texture2D:
	var path := art_dir.path_join(name + ".png")
	if ResourceLoader.exists(path):
		return load(path)
	return null
