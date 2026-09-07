class_name SpriteAnimator
extends Node
## Animação por quadros reais (PNGs separados). Sem deformar o sprite.
## frames: {"idle": [Texture2D,...], "attack": [...], "hurt": [...], "death": [...]}

var sprite: Sprite2D
var frames: Dictionary = {}
var target_px := 80.0
var fit_by_height := true
var idle_fps := 4.0
var _t := 0.0
var _idx := 0
var _state := "idle"
var _state_left := 0.0
var _rng := RandomNumberGenerator.new()
var _hold := 0.25


func setup(spr: Sprite2D, frame_dict: Dictionary, px: float, by_height: bool = true) -> void:
	sprite = spr
	frames = frame_dict
	target_px = px
	fit_by_height = by_height
	_rng.seed = spr.get_instance_id()
	_state = "idle"
	_idx = 0
	_apply()


func has_anim(name: String) -> bool:
	return frames.has(name) and not (frames[name] as Array).is_empty()


## Toca um estado temporário (attack/hurt) e volta ao idle.
func play(name: String, seconds: float) -> void:
	if not has_anim(name):
		return
	_state = name
	_state_left = seconds
	_idx = 0
	_t = 0.0
	_apply()


func play_loop(name: String) -> void:
	if not has_anim(name):
		return
	_state = name
	_state_left = -1.0
	_idx = 0
	_apply()


func _process(delta: float) -> void:
	if sprite == null or not has_anim(_state):
		return
	if _state_left > 0.0:
		_state_left -= delta
		if _state_left <= 0.0:
			_state = "idle"
			_idx = 0
			_apply()
			return
	var list: Array = frames[_state]
	if list.size() <= 1:
		return
	_t += delta
	var interval := 1.0 / idle_fps
	if _state == "idle":
		interval = _hold
	if _t >= interval:
		_t = 0.0
		_idx = (_idx + 1) % list.size()
		if _state == "idle":
			# Idle orgânico: quadro base dura mais, variações duram menos.
			_hold = _rng.randf_range(0.5, 1.1) if _idx == 0 else _rng.randf_range(0.2, 0.4)
		_apply()


func _apply() -> void:
	if sprite == null or not has_anim(_state):
		return
	var list: Array = frames[_state]
	var tex: Texture2D = list[clampi(_idx, 0, list.size() - 1)]
	if tex == null:
		return
	var flip := sprite.flip_h
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Escala fixa calculada pelo quadro-base (os demais quadros já estão registrados a ele).
	var base_tex: Texture2D = frames.idle[0] if has_anim("idle") else tex
	var dim := float(base_tex.get_height()) if fit_by_height else float(base_tex.get_width())
	var s := target_px / maxf(dim, 1.0)
	sprite.scale = Vector2(s, s)
	sprite.set_meta("base_scale", sprite.scale)
	sprite.flip_h = flip


## Carrega quadros de uma pasta pelo prefixo: base + _idle2/_idle3, _attack, _hurt/_hit, _death, _mid/_up.
static func load_frames(art_dir: String, base_name: String) -> Dictionary:
	var out := {"idle": [], "attack": [], "hurt": [], "death": [], "flap": []}
	var base_path := art_dir.path_join(base_name + ".png")
	if not ResourceLoader.exists(base_path):
		return out
	var base: Texture2D = load(base_path)
	out.idle.append(base)
	for suffix in ["idle2", "idle3", "idle4", "idle5", "idle6", "idle7", "idle8"]:
		var p := art_dir.path_join("%s_%s.png" % [base_name, suffix])
		if ResourceLoader.exists(p):
			out.idle.append(load(p))
	for pair in [["attack", "attack"], ["hurt", "hurt"], ["hit", "hurt"], ["death", "death"]]:
		var p := art_dir.path_join("%s_%s.png" % [base_name, pair[0]])
		if ResourceLoader.exists(p):
			out[pair[1]].append(load(p))
	# Ciclo de asas: base(aberta) -> mid -> up -> mid
	var mid := art_dir.path_join(base_name + "_mid.png")
	var up := art_dir.path_join(base_name + "_up.png")
	if ResourceLoader.exists(up):
		out.flap.append(base)
		if ResourceLoader.exists(mid):
			out.flap.append(load(mid))
		out.flap.append(load(up))
		if ResourceLoader.exists(mid):
			out.flap.append(load(mid))
	return out
