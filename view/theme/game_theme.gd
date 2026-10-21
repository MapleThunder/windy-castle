class_name GameTheme
extends RefCounted
## The dark fantasy UI theme, built in code so the palette lives in one place.

const PANEL := Color("14121c", 0.92)
const BORDER := Color("3a3350")
const HIGHLIGHT := Color("4b4266")
const ACCENT := Color("e0a050")
const TEXT := Color("e8e2d0")
const DIM := Color("8d86a0")
const HP := Color("c0392b")
const MP := Color("3d6fd6")
const FONT_SIZE := 14


static func panel_box(border := BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb


static func bar_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	var button := panel_box()
	button.set_content_margin_all(6)
	t.set_stylebox("normal", "Button", button)
	var hover := panel_box(ACCENT)
	hover.set_content_margin_all(6)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.5)
	track.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "LineEdit", panel_box())
	t.set_stylebox("focus", "LineEdit", panel_box(ACCENT))
	return t
