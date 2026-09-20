class_name ResultsScreen
extends Control
## Fim de jogo / vitória: pontuação final, recorde, reiniciar ou voltar ao menu.

var _title: Label
var _score: Label
var _record: Label
var _restart_btn: Button
var _details: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
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
	_title = UITheme.make_label(Loc.t("game_over"), 56, UITheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_title)
	root.add_child(UITheme.make_label(Loc.t("final_score"), 22, UITheme.BRONZE_LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_score = UITheme.make_label("0", 64, UITheme.IVORY, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_score)
	_record = UITheme.make_label("", 26, UITheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_record)
	_details = UITheme.make_label("", 18, Color(0.91, 0.87, 0.78, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_details)
	root.add_child(HSeparator.new())
	_restart_btn = _button(root, Loc.t("menu_restart"), func(): AudioManager.play_sfx("ui_confirm"); GameManager.restart_game())
	_button(root, Loc.t("menu_to_menu"), func(): AudioManager.play_sfx("ui_back"); GameManager.return_to_menu())
	GameManager.game_ended.connect(_on_game_ended)
	visibility_changed.connect(func():
		if visible:
			await get_tree().process_frame
			_restart_btn.grab_focus()
	)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UITheme.style_button(b)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _on_game_ended(won: bool, final_score: int, is_record: bool) -> void:
	_title.text = Loc.t("victory") if won else Loc.t("game_over")
	_title.add_theme_color_override("font_color", UITheme.GOLD if won else UITheme.DANGER)
	_score.text = ScoreManager.format_full(final_score)
	_record.text = Loc.t("new_record") if is_record else (Loc.t("high_score") + ": " + ScoreManager.format_full(SaveManager.high_score))
	var t := GameManager.table
	if t != null:
		_details.text = "%s: %d   Tempo: %d s   Multiball: %d   Bolas salvas: %d" % [Loc.t("seed"), GameManager.run_seed, int(GameManager.game_time), t.stats.multiballs, t.stats.saved]
	if won:
		AudioManager.play_sfx("victory", 0.0, 0.0)
	else:
		AudioManager.play_sfx("game_over", 0.0, 0.0)
