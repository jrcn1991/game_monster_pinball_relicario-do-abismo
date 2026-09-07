extends Node
## AudioManager: pool de players de SFX, música com crossfade, buses separados.
## Todos os arquivos são locais (res://). Nenhum carregamento por URL.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 24

var _sfx_cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _current_track := ""
var _last_play_time: Dictionary = {}  # name -> msec, evita spam do mesmo som no mesmo frame
var muted_sfx := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_a)
	add_child(_music_b)
	_music_current = _music_a


func _load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var path := SFX_DIR + sfx_name + ".wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		push_warning("AudioManager: SFX ausente: %s" % path)
	_sfx_cache[sfx_name] = stream
	return stream


## Toca um efeito. pitch_var: variação aleatória de pitch (0.0 = nenhuma). volume_db opcional.
func play_sfx(sfx_name: String, pitch_var: float = 0.05, volume_db: float = 0.0, min_interval_ms: int = 30) -> void:
	if muted_sfx:
		return
	var now := Time.get_ticks_msec()
	if _last_play_time.has(sfx_name) and now - int(_last_play_time[sfx_name]) < min_interval_ms:
		return
	_last_play_time[sfx_name] = now
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var) if pitch_var > 0.0 else 1.0
	p.play()


func play_music(track: String, fade_seconds: float = 1.0) -> void:
	if track == _current_track:
		return
	_current_track = track
	var path := MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: música ausente: %s" % path)
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono -> frames
	var next := _music_b if _music_current == _music_a else _music_a
	next.stream = stream
	next.volume_db = -40.0
	next.play()
	var prev := _music_current
	_music_current = next
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next, "volume_db", 0.0, fade_seconds)
	if prev.playing:
		tw.tween_property(prev, "volume_db", -40.0, fade_seconds)
		tw.chain().tween_callback(prev.stop)


func stop_music(fade_seconds: float = 1.0) -> void:
	_current_track = ""
	if _music_current.playing:
		var tw := create_tween()
		tw.tween_property(_music_current, "volume_db", -40.0, fade_seconds)
		tw.tween_callback(_music_current.stop)


func stop_all_sfx() -> void:
	for p in _pool:
		p.stop()
