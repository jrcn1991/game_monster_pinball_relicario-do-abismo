extends Node
## Cena principal: instancia a mesa e as telas de UI e reage aos estados do GameManager.

var table: GameTable
var hud: HUD
var main_menu: MainMenu
var pause_menu: PauseMenu
var results: ResultsScreen
var debug_overlay: DebugOverlay
var effects: EffectsLayer
var ui_layer: CanvasLayer
var overlay_layer: CanvasLayer
var autoplay := false
var _autoplay_timer := 0.0
var _screenshot_dir := ""
var _shot_index := 0
var _shot_timer := 0.0
var _autoplay_stage := 0


func _ready() -> void:
	var table_scene: PackedScene = load("res://scenes/table/GameTable.tscn")
	table = table_scene.instantiate()
	table.position = Vector2(550, 0)
	add_child(table)
	effects = EffectsLayer.new()
	effects.name = "Effects"
	table.add_child(effects)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 5
	add_child(ui_layer)
	overlay_layer = CanvasLayer.new()
	overlay_layer.name = "Overlay"
	overlay_layer.layer = 10
	add_child(overlay_layer)
	effects.setup(table, overlay_layer)
	var feel := HitFeel.new()
	feel.name = "HitFeel"
	add_child(feel)
	feel.setup(table)
	hud = HUD.new()
	hud.name = "HUD"
	ui_layer.add_child(hud)
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	ui_layer.add_child(main_menu)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	ui_layer.add_child(pause_menu)
	results = ResultsScreen.new()
	results.name = "Results"
	ui_layer.add_child(results)
	var touch := TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "Debug"
	overlay_layer.add_child(debug_overlay)
	GameManager.state_changed.connect(_on_state_changed)
	_apply_state(GameManager.state)
	# Modo de verificação visual automática (usado por ferramentas): --autoplay e --screenshots=DIR
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			autoplay = true
		elif arg.begins_with("--screenshots="):
			_screenshot_dir = arg.trim_prefix("--screenshots=")
		elif arg.begins_with("--stage="):
			_autoplay_stage = int(arg.trim_prefix("--stage=")) - 1
	if autoplay:
		call_deferred("_start_autoplay")


func _on_state_changed(_old: int, new_state: int) -> void:
	_apply_state(new_state)


func _apply_state(state: int) -> void:
	var S := GameManager.State
	main_menu.visible = state == S.MENU
	pause_menu.visible = state == S.PAUSED
	results.visible = state in [S.GAME_OVER, S.RESULTS]
	hud.visible = state != S.MENU
	table.visible = state != S.MENU


# --- Autoplay: joga sozinho para gerar capturas de tela e validar visualmente ---------
func _start_autoplay() -> void:
	table.input_override = true
	GameManager.start_new_game(12345)
	if _autoplay_stage > 0:
		table.apply_stage(_autoplay_stage)


func _physics_process(delta: float) -> void:
	if not autoplay:
		return
	_autoplay_timer += delta
	if GameManager.state == GameManager.State.SERVE and table.plunger.has_ball() and _autoplay_timer > 1.0:
		table.plunger.launch(0.8)
		_autoplay_timer = 0.0
	elif table.plunger.has_ball() and _autoplay_timer > 1.5:
		table.plunger.launch(0.8)
		_autoplay_timer = 0.0
	# IA simples de flipper: bate quando a bola está caindo perto da pá.
	var left := false
	var right := false
	for b in table.active_balls:
		if not is_instance_valid(b) or b.in_plunger_lane:
			continue
		if b.position.y > 880.0 and b.linear_velocity.y > 0.0:
			if b.position.x < 380.0 and b.position.x > 200.0:
				left = true
			elif b.position.x >= 380.0 and b.position.x < 560.0:
				right = true
	table.flipper_left.set_pressed(left)
	table.flipper_right.set_pressed(right)
	if _screenshot_dir != "":
		_shot_timer += delta
		if _shot_timer > 3.0 and _shot_index < 8:
			_shot_timer = 0.0
			_take_screenshot()
		if _shot_index >= 8:
			get_tree().quit()


func _take_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _screenshot_dir.path_join("shot_%02d.png" % _shot_index)
	img.save_png(path)
	print("screenshot: ", path)
	_shot_index += 1
