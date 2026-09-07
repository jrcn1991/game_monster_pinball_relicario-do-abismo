extends Node
## SaveManager: recorde, volume, tela cheia, acessibilidade. Arquivo local em user://.

const DEFAULT_SAVE_PATH := "user://relicario.cfg"
var save_path: String = DEFAULT_SAVE_PATH

signal settings_changed()

var high_score: int = 0
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = false
var reduce_flash: bool = false
var reduce_shake: bool = false
var high_contrast: bool = false
var games_played: int = 0
var last_seed: int = 0


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(save_path)
	if err != OK:
		return
	high_score = int(cfg.get_value("progress", "high_score", 0))
	games_played = int(cfg.get_value("progress", "games_played", 0))
	last_seed = int(cfg.get_value("progress", "last_seed", 0))
	master_volume = float(cfg.get_value("audio", "master", 1.0))
	music_volume = float(cfg.get_value("audio", "music", 0.8))
	sfx_volume = float(cfg.get_value("audio", "sfx", 1.0))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	reduce_flash = bool(cfg.get_value("access", "reduce_flash", false))
	reduce_shake = bool(cfg.get_value("access", "reduce_shake", false))
	high_contrast = bool(cfg.get_value("access", "high_contrast", false))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "high_score", high_score)
	cfg.set_value("progress", "games_played", games_played)
	cfg.set_value("progress", "last_seed", last_seed)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("access", "reduce_flash", reduce_flash)
	cfg.set_value("access", "reduce_shake", reduce_shake)
	cfg.set_value("access", "high_contrast", high_contrast)
	var err := cfg.save(save_path)
	if err != OK:
		push_error("SaveManager: falha ao salvar (%d)" % err)


func apply_settings() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


func submit_score(score: int) -> bool:
	games_played += 1
	var is_record := score > high_score
	if is_record:
		high_score = score
	save_settings()
	return is_record
