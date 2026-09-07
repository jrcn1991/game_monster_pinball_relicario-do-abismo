class_name UITheme
## Estilos compartilhados de UI (marfim sobre pedra negra com molduras de bronze).

const IVORY := Color(0.91, 0.87, 0.78)
const BRONZE := Color(0.55, 0.38, 0.22)
const BRONZE_LIGHT := Color(0.84, 0.66, 0.37)
const VIOLET := Color(0.48, 0.17, 0.75)
const VIOLET_LIGHT := Color(0.78, 0.49, 1.0)
const DANGER := Color(0.9, 0.22, 0.27)
const GOLD := Color(0.96, 0.83, 0.37)
const STONE := Color(0.14, 0.14, 0.22)
const STONE_LIGHT := Color(0.22, 0.21, 0.30)
const BG := Color(0.0353, 0.0392, 0.0706)


static func panel_style(bg: Color = Color(0.0353, 0.0392, 0.0706, 0.92), border: Color = BRONZE, border_w: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	return sb


static func bar_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	return sb


static func make_label(text: String, size: int, color: Color = IVORY, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", maxi(2, size / 8))
	l.horizontal_alignment = align
	return l


static func style_button(b: Button, size: int = 30) -> void:
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", IVORY)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", VIOLET_LIGHT)
	var normal := panel_style(Color(0.14, 0.14, 0.22, 0.9), BRONZE, 2)
	var hover := panel_style(Color(0.22, 0.21, 0.30, 0.95), BRONZE_LIGHT, 2)
	var focus := panel_style(Color(0.22, 0.21, 0.30, 0.95), GOLD, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("pressed", hover)
	b.custom_minimum_size = Vector2(320, 56)
