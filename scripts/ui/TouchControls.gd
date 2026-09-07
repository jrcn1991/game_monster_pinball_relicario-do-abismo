class_name TouchControls
extends CanvasLayer
## Controles de toque (celular/tablet): metade esquerda = flipper esquerdo, metade direita =
## flipper direito, botão LANÇAR (segurar carrega), MAGIA e PAUSA. Só aparece em telas de toque
## e só recebe entrada durante a partida (menus usam os próprios botões).

var _buttons: Array[TouchScreenButton] = []
var _labels: Array[Control] = []
var _enabled := false


func _ready() -> void:
	layer = 8
	_enabled = DisplayServer.is_touchscreen_available()
	_make_zone("flipper_left", Rect2(0, 480, 950, 600), "◀ FLIPPER", false)
	_make_zone("flipper_right", Rect2(970, 480, 950, 600), "FLIPPER ▶", false)
	_make_zone("plunger", Rect2(1420, 130, 460, 300), "LANÇAR\n(segure)", true)
	_make_zone("magic", Rect2(40, 130, 460, 300), "MAGIA", true)
	_make_zone("pause", Rect2(810, 0, 300, 110), "PAUSA", true)
	GameManager.state_changed.connect(func(_o, _n): _refresh())
	_refresh()


func _make_zone(action: String, rect: Rect2, text: String, boxed: bool) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	b.passby_press = true
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	b.shape = shape
	b.shape_centered = false
	b.position = rect.position
	add_child(b)
	_buttons.append(b)
	var panel := Control.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if boxed:
		var box := ColorRect.new()
		box.color = Color(0.48, 0.17, 0.75, 0.18)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
	var l := UITheme.make_label(text, 28, Color(0.91, 0.87, 0.78, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if boxed else VERTICAL_ALIGNMENT_BOTTOM
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	add_child(panel)
	_labels.append(panel)


func _refresh() -> void:
	var show := _enabled and GameManager.is_in_game()
	visible = show
