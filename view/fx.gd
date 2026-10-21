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


func update_level() -> void:
	dust.emitting = world.game.level.depth > 0


func _process(_delta: float) -> void:
	if world == null:
		return
	var player_node := world.actor_node(world.game.player.id)
	if player_node != null:
		dust.position = player_node.position
