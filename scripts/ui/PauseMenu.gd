class_name PauseMenu
extends Control
## Menu de pausa: continuar, opções, reiniciar, menu principal. Mostra pontuação completa.

var _score_label: Label
var _resume_btn: Button
var _options: OptionsPanel
var _main_box: VBoxContainer
var _options_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	root.add_child(UITheme.make_label(Loc.t("paused"), 48, UITheme.BRONZE_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_score_label = UITheme.make_label("", 22, UITheme.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_score_label)
	root.add_child(HSeparator.new())
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	root.add_child(_main_box)
	_resume_btn = _button(_main_box, Loc.t("menu_resume"), func(): AudioManager.play_sfx("ui_confirm"); GameManager.resume_game())
	_button(_main_box, Loc.t("menu_options"), func(): AudioManager.play_sfx("ui_confirm"); _main_box.visible = false; _options_box.visible = true; _options.focus_first())
	_button(_main_box, Loc.t("menu_restart"), func(): AudioManager.play_sfx("ui_confirm"); GameManager.restart_game())
	_button(_main_box, Loc.t("menu_to_menu"), func(): AudioManager.play_sfx("ui_back"); GameManager.return_to_menu())
	_options_box = VBoxContainer.new()
	_options_box.visible = false
	root.add_child(_options_box)
	_options = OptionsPanel.new()
	_options_box.add_child(_options)
	_button(_options_box, Loc.t("menu_back"), func(): AudioManager.play_sfx("ui_back"); _options_box.visible = false; _main_box.visible = true; _resume_btn.grab_focus())
	visibility_changed.connect(_on_visibility_changed)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b)
	b.pressed.connect(callback)
	b.focus_entered.connect(func(): AudioManager.play_sfx("ui_move", 0.05, -8.0))
	parent.add_child(b)
	return b


func _on_visibility_changed() -> void:
	if visible:
		_main_box.visible = true
		_options_box.visible = false
		_score_label.text = "%s: %s   %s: x%d   %s: %d" % [Loc.t("score"), ScoreManager.format_full(ScoreManager.score), Loc.t("multiplier"), ScoreManager.multiplier, Loc.t("seed"), GameManager.run_seed]
		await get_tree().process_frame
		_resume_btn.grab_focus()
