class_name HUD
extends Control
## HUD: placar, bolas, multiplicador, combo, mana, selos, vida do chefe, mensagens.

var score_label: Label
var score_full_label: Label
var balls_label: Label
var mult_label: Label
var combo_label: Label
var combo_bar: ProgressBar
var mana_bar: ProgressBar
var mana_label: Label
var magic_label: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_phase_label: Label
var seal_labels: Dictionary = {}
var message_label: Label
var sub_message_label: Label
var save_label: Label
var tilt_bar: ProgressBar
var lock_label: Label
var record_label: Label
var seed_label: Label
var _message_left := 0.0
var _messages: Array = []  # fila de [texto, segundos]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_left_panel()
	_build_right_panel()
	_build_center()
	ScoreManager.score_changed.connect(_on_score)
	ScoreManager.combo_changed.connect(_on_combo)
	ScoreManager.multiplier_changed.connect(_on_mult)
	GameManager.balls_changed.connect(_on_balls)
	GameManager.game_started.connect(_on_game_started)
	SignalBus.mana_changed.connect(_on_mana)
	SignalBus.magic_activated.connect(func(_s): magic_label.text = Loc.t("magic_on"); magic_label.add_theme_color_override("font_color", UITheme.GOLD))
	SignalBus.magic_ended.connect(func(): _refresh_magic_label())
	SignalBus.hud_message.connect(show_message)
	SignalBus.ball_save_changed.connect(_on_ball_save)
	SignalBus.seal_broken.connect(_on_seal)
	SignalBus.boss_health_changed.connect(_on_boss_health)
	SignalBus.boss_phase_changed.connect(_on_boss_phase)
	SignalBus.boss_awakened.connect(func(): boss_box.visible = true)
	SignalBus.boss_defeated.connect(func(): boss_phase_label.text = Loc.t("boss_defeated"))
	SignalBus.bonus_sequence_started.connect(func(_s): boss_phase_label.text = Loc.t("bonus_time"))
	SignalBus.bonus_sequence_ended.connect(func(): boss_box.visible = false)
	SignalBus.tilt_warning.connect(func(level): tilt_bar.value = level)
	SignalBus.tilt_triggered.connect(func(): tilt_bar.value = 1.0; tilt_bar.modulate = UITheme.DANGER)
	SignalBus.tilt_recovered.connect(func(): tilt_bar.value = 0.0; tilt_bar.modulate = Color.WHITE)
	SignalBus.ball_locked.connect(func(n): lock_label.text = "TRAVA %d/2" % n)
	SignalBus.multiball_started.connect(func(_n): lock_label.text = Loc.t("multiball"))
	SignalBus.multiball_ended.connect(func(): lock_label.text = "TRAVA 0/2")
	_on_score(0)
	_on_balls(GameManager.balls_left)
	_on_mult(1)
	_on_combo(0, 0.0)
	_on_mana(0, 100)


func _panel(x: float, w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(x, 84)
	p.size = Vector2(w, 940)
	p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.0353, 0.0392, 0.0706, 0.0), Color(0, 0, 0, 0), 0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _build_left_panel() -> void:
	var bgp := TextureRect.new()
	if ResourceLoader.exists("res://assets/art/side_panel.png"):
		bgp.texture = load("res://assets/art/side_panel.png")
	bgp.position = Vector2(0, 0)
	bgp.size = Vector2(550, 1080)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgp)
	var p := _panel(60, 430)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.make_label(Loc.t("title"), 30, UITheme.BRONZE_LIGHT))
	v.add_child(UITheme.make_label(Loc.t("subtitle"), 18, UITheme.VIOLET_LIGHT))
	v.add_child(HSeparator.new())
	v.add_child(UITheme.make_label(Loc.t("score"), 22, UITheme.BRONZE_LIGHT))
	score_label = UITheme.make_label("0", 64, UITheme.IVORY)
	v.add_child(score_label)
	score_full_label = UITheme.make_label("0", 18, Color(0.91, 0.87, 0.78, 0.6))
	v.add_child(score_full_label)
	v.add_child(HSeparator.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	v.add_child(h)
	var vb := VBoxContainer.new(); h.add_child(vb)
	vb.add_child(UITheme.make_label(Loc.t("balls"), 18, UITheme.BRONZE_LIGHT))
	balls_label = UITheme.make_label("3", 44); vb.add_child(balls_label)
	var vm := VBoxContainer.new(); h.add_child(vm)
	vm.add_child(UITheme.make_label(Loc.t("multiplier"), 18, UITheme.BRONZE_LIGHT))
	mult_label = UITheme.make_label("x1", 44, UITheme.GOLD); vm.add_child(mult_label)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.make_label(Loc.t("combo"), 18, UITheme.BRONZE_LIGHT))
	combo_label = UITheme.make_label("0", 40, UITheme.VIOLET_LIGHT)
	v.add_child(combo_label)
	combo_bar = ProgressBar.new()
	combo_bar.max_value = 1.0
	combo_bar.value = 0.0
	combo_bar.show_percentage = false
	combo_bar.custom_minimum_size = Vector2(0, 12)
	combo_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.VIOLET_LIGHT))
	combo_bar.add_theme_stylebox_override("background", UITheme.bar_style(UITheme.STONE))
	v.add_child(combo_bar)
	v.add_child(HSeparator.new())
	v.add_child(UITheme.make_label("TILT", 16, UITheme.BRONZE_LIGHT))
	tilt_bar = ProgressBar.new()
	tilt_bar.max_value = 1.0
	tilt_bar.show_percentage = false
	tilt_bar.custom_minimum_size = Vector2(0, 10)
	tilt_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.DANGER))
	tilt_bar.add_theme_stylebox_override("background", UITheme.bar_style(UITheme.STONE))
	v.add_child(tilt_bar)
	v.add_child(HSeparator.new())
	record_label = UITheme.make_label(Loc.t("high_score") + ": " + ScoreManager.format_full(SaveManager.high_score), 18, Color(0.91, 0.87, 0.78, 0.7))
	v.add_child(record_label)
	seed_label = UITheme.make_label(Loc.t("seed") + ": -", 14, Color(0.91, 0.87, 0.78, 0.5))
	v.add_child(seed_label)
	v.add_child(UITheme.make_label(Loc.t("debug_hint"), 14, Color(0.91, 0.87, 0.78, 0.4)))


func _build_right_panel() -> void:
	var bgp := TextureRect.new()
	if ResourceLoader.exists("res://assets/art/side_panel.png"):
		bgp.texture = load("res://assets/art/side_panel.png")
	bgp.flip_h = true
	bgp.position = Vector2(1370, 0)
	bgp.size = Vector2(550, 1080)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgp)
	var p := _panel(1430, 430)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.make_label(Loc.t("mana"), 22, UITheme.BRONZE_LIGHT))
	mana_bar = ProgressBar.new()
	mana_bar.max_value = 100
	mana_bar.show_percentage = false
	mana_bar.custom_minimum_size = Vector2(0, 26)
	mana_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.VIOLET))
	mana_bar.add_theme_stylebox_override("background", UITheme.bar_style(UITheme.STONE))
	v.add_child(mana_bar)
	mana_label = UITheme.make_label("0 / 100", 18)
	v.add_child(mana_label)
	magic_label = UITheme.make_label("", 18, UITheme.VIOLET_LIGHT)
	v.add_child(magic_label)
	_refresh_magic_label()
	v.add_child(HSeparator.new())
	v.add_child(UITheme.make_label(Loc.t("seals"), 22, UITheme.BRONZE_LIGHT))
	for id in ["targets", "guardian", "runes"]:
		var l := UITheme.make_label("○  " + Loc.t("seal_" + id), 22, Color(0.91, 0.87, 0.78, 0.6))
		seal_labels[id] = l
		v.add_child(l)
	v.add_child(HSeparator.new())
	lock_label = UITheme.make_label("TRAVA 0/2", 18, UITheme.VIOLET_LIGHT)
	v.add_child(lock_label)
	save_label = UITheme.make_label("", 18, UITheme.GOLD)
	v.add_child(save_label)
	v.add_child(HSeparator.new())
	boss_box = VBoxContainer.new()
	boss_box.visible = false
	v.add_child(boss_box)
	boss_box.add_child(UITheme.make_label(Loc.t("boss"), 22, UITheme.DANGER))
	boss_bar = ProgressBar.new()
	boss_bar.max_value = 60
	boss_bar.value = 60
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 26)
	boss_bar.add_theme_stylebox_override("fill", UITheme.bar_style(UITheme.DANGER))
	boss_bar.add_theme_stylebox_override("background", UITheme.bar_style(UITheme.STONE))
	boss_box.add_child(boss_bar)
	boss_phase_label = UITheme.make_label(Loc.t("boss_phase") % 1, 18)
	boss_box.add_child(boss_phase_label)
	v.add_child(HSeparator.new())
	var ctrl := UITheme.make_label(Loc.t("controls_body"), 13, Color(0.91, 0.87, 0.78, 0.55))
	ctrl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ctrl)


func _build_center() -> void:
	message_label = UITheme.make_label("", 40, UITheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	message_label.position = Vector2(550, 60)
	message_label.size = Vector2(820, 60)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_label)
	sub_message_label = UITheme.make_label("", 22, UITheme.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	sub_message_label.position = Vector2(550, 1000)
	sub_message_label.size = Vector2(820, 40)
	sub_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub_message_label)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			message_label.text = ""
			_next_message()
	var t := GameManager.table
	if t != null and GameManager.state == GameManager.State.SERVE:
		sub_message_label.text = Loc.t("press_launch")
	elif t != null and t.plunger != null and t.plunger.has_ball():
		sub_message_label.text = Loc.t("press_launch")
	else:
		sub_message_label.text = ""


func show_message(text: String, seconds: float) -> void:
	if _message_left > 0.0 and message_label.text != "":
		if _messages.size() < 4:
			_messages.append([text, seconds])
		return
	message_label.text = text
	_message_left = seconds


func _next_message() -> void:
	if _messages.is_empty():
		return
	var m: Array = _messages.pop_front()
	message_label.text = m[0]
	_message_left = m[1]


func _on_score(score: int) -> void:
	score_label.text = ScoreManager.format_short(score)
	score_full_label.text = ScoreManager.format_full(score)


func _on_combo(combo: int, seconds_left: float) -> void:
	combo_label.text = str(combo)
	combo_bar.value = clampf(seconds_left / ScoreManager.COMBO_WINDOW, 0.0, 1.0)


func _on_mult(m: int) -> void:
	mult_label.text = "x%d" % m


func _on_balls(n: int) -> void:
	balls_label.text = str(maxi(n, 0))


func _on_mana(cur: int, maxv: int) -> void:
	mana_bar.max_value = maxv
	mana_bar.value = cur
	mana_label.text = "%d / %d" % [cur, maxv]
	_refresh_magic_label()


func _refresh_magic_label() -> void:
	var t := GameManager.table
	if t != null and t.magic != null and t.magic.active:
		return
	if t != null and t.magic != null and t.magic.can_cast():
		magic_label.text = Loc.t("magic_ready")
		magic_label.add_theme_color_override("font_color", UITheme.GOLD)
	else:
		magic_label.text = "Bola Consagrada: 100 de mana"
		magic_label.add_theme_color_override("font_color", Color(0.91, 0.87, 0.78, 0.5))


func _on_ball_save(active: bool, seconds: float) -> void:
	save_label.text = (Loc.t("ball_save_on") + " %.0f s" % ceil(seconds)) if active else ""


func _on_seal(seal_id: String, _count: int, _total: int) -> void:
	if seal_labels.has(seal_id):
		var l: Label = seal_labels[seal_id]
		l.text = "●  " + Loc.t("seal_" + seal_id)
		l.add_theme_color_override("font_color", UITheme.GOLD)


func _reset_seals() -> void:
	for id in seal_labels:
		var l: Label = seal_labels[id]
		l.text = "○  " + Loc.t("seal_" + id)
		l.add_theme_color_override("font_color", Color(0.91, 0.87, 0.78, 0.6))


func _on_boss_health(cur: int, maxv: int) -> void:
	boss_bar.max_value = maxv
	boss_bar.value = cur


func _on_boss_phase(phase: int) -> void:
	# phase: 1..3 = fases, 4 = derrotado
	if phase >= 1 and phase <= 3:
		boss_phase_label.text = Loc.t("boss_phase") % phase


func _on_game_started(seed_value: int) -> void:
	_reset_seals()
	boss_box.visible = false
	lock_label.text = "TRAVA 0/2"
	save_label.text = ""
	message_label.text = ""
	_messages.clear()
	_message_left = 0.0
	seed_label.text = Loc.t("seed") + ": %d" % seed_value
	record_label.text = Loc.t("high_score") + ": " + ScoreManager.format_full(SaveManager.high_score)
	tilt_bar.value = 0.0
	tilt_bar.modulate = Color.WHITE
