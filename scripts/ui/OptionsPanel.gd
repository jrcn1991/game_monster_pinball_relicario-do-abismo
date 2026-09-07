class_name OptionsPanel
extends VBoxContainer
## Painel de opções reutilizado no menu e na pausa: volumes, tela cheia, acessibilidade.

var _master: HSlider
var _music: HSlider
var _sfx: HSlider
var _fullscreen: CheckButton
var _flash: CheckButton
var _shake: CheckButton
var _contrast: CheckButton


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_master = _slider(Loc.t("opt_master"), SaveManager.master_volume, func(v): SaveManager.master_volume = v; _apply())
	_music = _slider(Loc.t("opt_music"), SaveManager.music_volume, func(v): SaveManager.music_volume = v; _apply())
	_sfx = _slider(Loc.t("opt_sfx"), SaveManager.sfx_volume, func(v): SaveManager.sfx_volume = v; _apply(); AudioManager.play_sfx("ui_move"))
	_fullscreen = _check(Loc.t("opt_fullscreen"), SaveManager.fullscreen, func(v): SaveManager.fullscreen = v; _apply())
	_flash = _check(Loc.t("opt_reduce_flash"), SaveManager.reduce_flash, func(v): SaveManager.reduce_flash = v; _apply())
	_shake = _check(Loc.t("opt_reduce_shake"), SaveManager.reduce_shake, func(v): SaveManager.reduce_shake = v; _apply())
	_contrast = _check(Loc.t("opt_high_contrast"), SaveManager.high_contrast, func(v): SaveManager.high_contrast = v; _apply())


func _apply() -> void:
	SaveManager.apply_settings()
	SaveManager.save_settings()


func _slider(label: String, value: float, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UITheme.make_label(label, 20)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 30)
	s.value_changed.connect(cb)
	h.add_child(s)
	add_child(h)
	return s


func _check(label: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", UITheme.IVORY)
	c.toggled.connect(cb)
	add_child(c)
	return c


func focus_first() -> void:
	_master.grab_focus()
