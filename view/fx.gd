class_name Fx
extends Node2D
## Ambient effects: dust motes drifting in the torchlight and a screen vignette.

var world: WorldView
var dust := CPUParticles2D.new()
var vignette_layer := CanvasLayer.new()


func setup(w: WorldView) -> void:
	world = w
	dust.amount = 40
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 150.0
	dust.gravity = Vector2(0, -2)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 5.0
	dust.direction = Vector2(1, 0)
	dust.spread = 180.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.85, 0.6, 0.0))
	ramp.set_color(1, Color(1, 0.85, 0.6, 0.0))
	ramp.add_point(0.5, Color(1, 0.85, 0.6, 0.35))
	dust.color_ramp = ramp
	add_child(dust)
	vignette_layer.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://view/shaders/vignette.gdshader")
	rect.material = mat
	vignette_layer.add_child(rect)
	add_child(vignette_layer)
	update_level()


## Burst of sparks where a blow lands.
func sparks(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.5, 1))
	ramp.set_color(1, Color(1, 0.4, 0.1, 0))
	p.color_ramp = ramp
	p.position = at
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.emitting = true


## A soft puff (doors) or a shimmer (found secrets).
func puff(at: Vector2, shimmer: bool) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 16 if shimmer else 8
	p.lifetime = 0.6 if shimmer else 0.3
	p.explosiveness = 0.8
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 14)
	p.gravity = Vector2(0, -20 if shimmer else 10)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 20.0
	p.spread = 180.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.9, 1, 0.9) if shimmer else Color(0.8, 0.75, 0.7, 0.5))
	ramp.set_color(1, Color(0.7, 0.9, 1, 0) if shimmer else Color(0.8, 0.75, 0.7, 0))
	p.color_ramp = ramp
	p.position = at
	p.finished.connect(p.queue_free)
	world.add_child(p)
	p.emitting = true


## Damage numbers and "miss": rise 12 px and fade over 0.6 s.
func float_text(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_override("font", GameTheme.HEADING)
	l.add_theme_font_size_override("font_size", 14)
	l.position = at + Vector2(-8, -28)
	l.z_index = 20
	world.add_child(l)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - 12, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(l.queue_free)


## Dropped items land with a small bounce.
func bounce_item_at(at: Vector2) -> void:
	for c in world.items.get_children():
		if c is Sprite2D and c.position == at:
			var t := c.create_tween()
			t.tween_property(c, "position:y", at.y - 8, 0.06).set_ease(Tween.EASE_OUT)
			t.tween_property(c, "position:y", at.y, 0.09).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func update_level() -> void:
	dust.emitting = world.game.level.depth > 0


func _process(_delta: float) -> void:
	if world == null:
		return
	var player_node := world.actor_node(world.game.player.id)
	if player_node != null:
		dust.position = player_node.position
