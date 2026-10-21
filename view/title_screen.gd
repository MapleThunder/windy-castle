class_name TitleScreen
extends Control
## The original title art over a dark backdrop with drifting embers.

signal chosen(choice: String)  # "new", "load", "options", "keys", "quit"

const CHOICES := [["New Game", "new"], ["Load Game", "load"], ["Options", "options"], ["Keyboard", "keys"], ["Quit", "quit"]]

var buttons := VBoxContainer.new()


func _ready() -> void:
	theme = GameTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK  # matches the title bitmap's own background
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 8.0
	embers.preprocess = 8.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 4.0
	embers.initial_velocity_max = 14.0
	embers.direction = Vector2(0, -1)
	embers.spread = 35.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.55, 0.2, 0))
	ramp.set_color(1, Color(1, 0.3, 0.1, 0))
	ramp.add_point(0.3, Color(1, 0.7, 0.3, 0.8))
	embers.color_ramp = ramp
	add_child(embers)
	resized.connect(func():
		embers.position = Vector2(size.x / 2, size.y + 10)
		embers.emission_rect_extents = Vector2(size.x / 2, 10))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	for bitmap in ["bitmaps/10.png", "bitmaps/11.png"]:  # source: exe — title and "Part One" art
		var art := TextureRect.new()
		art.texture = ArtPack._load(ArtPack.ORIGINAL + "/" + bitmap)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = art.texture.get_size() * (0.9 if bitmap.ends_with("10.png") else 0.6)
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(art)
	buttons.add_theme_constant_override("separation", 6)
	for c in CHOICES:
		var b := Button.new()
		b.text = c[0]
		b.custom_minimum_size = Vector2(220, 0)
		b.pressed.connect(func(): chosen.emit(c[1]))
		buttons.add_child(b)
	var holder := CenterContainer.new()
	holder.add_child(buttons)
	v.add_child(holder)
	buttons.get_child(0).grab_focus.call_deferred()
