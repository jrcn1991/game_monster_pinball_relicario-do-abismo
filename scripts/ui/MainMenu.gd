class_name MainMenu
extends Control
## Tela inicial: jogar, opções, créditos, sair. Teclado e gamepad.

var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _credits_box: VBoxContainer
var _record_label: Label
var _first_button: Button
var _options_panel: OptionsPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/art/menu_bg.png"):
		bg.texture = load("res://assets/art/menu_bg.png")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	root.add_child(UITheme.make_label(Loc.t("title"), 64, UITheme.BRONZE_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(UITheme.make_label(Loc.t("subtitle"), 24, UITheme.VIOLET_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_record_label = UITheme.make_label("", 20, UITheme.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_record_label)
	root.add_child(HSeparator.new())
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	root.add_child(_main_box)
	_first_button = _button(_main_box, Loc.t("menu_play"), func(): AudioManager.play_sfx("ui_confirm"); GameManager.start_new_game())
	_button(_main_box, Loc.t("menu_options"), func(): AudioManager.play_sfx("ui_confirm"); _show(_options_box))
	_button(_main_box, Loc.t("menu_credits"), func(): AudioManager.play_sfx("ui_confirm"); _show(_credits_box))
	if not OS.has_feature("web"):
		_button(_main_box, Loc.t("menu_quit"), func(): get_tree().quit())
	var ctrl := UITheme.make_label(Loc.t("controls_body"), 15, Color(0.91, 0.87, 0.78, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	_main_box.add_child(ctrl)
	# Opções
	_options_box = VBoxContainer.new()
	_options_box.visible = false
	root.add_child(_options_box)
	_options_panel = OptionsPanel.new()
	_options_box.add_child(_options_panel)
	_button(_options_box, Loc.t("menu_back"), func(): AudioManager.play_sfx("ui_back"); _show(_main_box))
	# Créditos
	_credits_box = VBoxContainer.new()
	_credits_box.visible = false
	root.add_child(_credits_box)
	var cr := UITheme.make_label(Loc.t("credits_body"), 18, UITheme.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	_credits_box.add_child(cr)
	_button(_credits_box, Loc.t("menu_back"), func(): AudioManager.play_sfx("ui_back"); _show(_main_box))
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b)
	b.pressed.connect(callback)
	b.focus_entered.connect(func(): AudioManager.play_sfx("ui_move", 0.05, -8.0))
	parent.add_child(b)
	return b


func _show(box: VBoxContainer) -> void:
	_main_box.visible = box == _main_box
	_options_box.visible = box == _options_box
	_credits_box.visible = box == _credits_box
	await get_tree().process_frame
	if box == _main_box:
		_first_button.grab_focus()
	else:
		for c in box.get_children():
			if c is Button:
				c.grab_focus()
				break
			if c is OptionsPanel:
				c.focus_first()
				break


func _on_visibility_changed() -> void:
	if visible:
		_record_label.text = Loc.t("high_score") + ": " + ScoreManager.format_full(SaveManager.high_score)
		_show(_main_box)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_start") and _main_box.visible and not (event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE and get_viewport().gui_get_focus_owner() is Slider):
		if get_viewport().gui_get_focus_owner() == null or get_viewport().gui_get_focus_owner() == _first_button:
			get_viewport().set_input_as_handled()
			AudioManager.play_sfx("ui_confirm")
			GameManager.start_new_game()
	elif event.is_action_pressed("ui_cancel") and not _main_box.visible:
		get_viewport().set_input_as_handled()
		AudioManager.play_sfx("ui_back")
		_show(_main_box)
