class_name EventPlayer
extends Node
## Plays a batch of engine events back as animation. The engine state is already final;
## this only moves sprites from where they were to where the events say they went.

signal finished
signal message_logged(text: String)
signal stats_changed
signal player_died(cause: String)

const MOVE_TIME := 0.08
const FAST_MOVE_TIME := 0.04
const LUNGE_TIME := 0.12
const FLASH_TIME := 0.06
const DIE_TIME := 0.2
const FADE_TIME := 0.15

var world: WorldView
var fast := false
var _busy := false
var _fade := ColorRect.new()


func setup(w: WorldView) -> void:
	world = w
	var layer := CanvasLayer.new()
	layer.layer = 10
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	add_child(layer)


func is_busy() -> bool:
	return _busy


func play(events: Array, previous_visible: Dictionary) -> void:
	_busy = true
	world.refresh_visibility(previous_visible)
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		if e["type"] == "moved":
			var batch := []
			while i < events.size() and events[i]["type"] == "moved":
				batch.append(events[i])
				i += 1
			await _moves(batch)
			continue
		await _one(e)
		i += 1
	world.refresh_entities()
	_check_sync()
	_busy = false
	finished.emit()


func _tween() -> Tween:
	return create_tween()


func _moves(batch: Array) -> void:
	var t: Tween = null
	for e in batch:
		var node := world.actor_node(e["actor_id"])
		if node == null:
			continue
		node.visible = node == world.actor_node(world.game.player.id) or world.game.visible.has(e["to"])
		if not node.visible:
			node.position = world.tile_to_px(e["to"])
			continue
		if t == null:
			t = _tween().set_parallel()
		t.tween_property(node, "position", world.tile_to_px(e["to"]), FAST_MOVE_TIME if fast else MOVE_TIME) \
			.from(world.tile_to_px(e["from"])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if t != null:
		await t.finished


func _one(e: Dictionary) -> void:
	match e["type"]:
		"attacked", "missed":
			await _attack(e)
		"died":
			await _die(e["actor_id"])
		"door_opened", "door_closed", "secret_found":
			world.refresh_tile(e["pos"])
			world.lighting.update_level()
			world.fx.puff(world.tile_to_px(e["pos"]), e["type"] == "secret_found")
		"item_dropped":
			world.refresh_entities()
			world.fx.bounce_item_at(world.tile_to_px(e["pos"]))
		"item_picked", "gold_picked":
			world.refresh_entities()
		"level_changed":
			await _fade_to(1.0)
			world.clear_actors()
			world.refresh_all()
			world.camera.reset_smoothing()
			await _fade_to(0.0)
		"message":
			message_logged.emit(e["text"])
		"stats_changed":
			stats_changed.emit()
		"player_died":
			player_died.emit(e.get("cause", ""))


func _attack(e: Dictionary) -> void:
	var att := world.actor_node(e["attacker_id"])
	var target := world.actor_node(e["target_id"])
	if att == null or target == null or not (att.visible or target.visible):
		return
	var hit: bool = e["type"] == "attacked"
	var home := att.position
	var toward := home.lerp(target.position, 0.25 if hit else 0.15)
	var t := _tween()
	t.tween_property(att, "position", toward, LUNGE_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(att, "position", home, LUNGE_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if hit:
		var flash := _tween()
		flash.tween_property(target, "modulate", Color(2.5, 2.5, 2.5), FLASH_TIME / 2.0).set_delay(LUNGE_TIME / 2.0)
		flash.tween_property(target, "modulate", Color.WHITE, FLASH_TIME / 2.0)
		world.fx.sparks(target.position)
		if Settings.get_opt("damage_numbers"):
			world.fx.float_text(target.position, str(e["damage"]), Color("ffd27a"))
	elif Settings.get_opt("damage_numbers"):
		world.fx.float_text(target.position, "miss", Color(0.7, 0.7, 0.75))
	await t.finished


func _die(id: int) -> void:
	var node := world.actor_node(id)
	if node == null or not node.visible:
		return
	var t := _tween().set_parallel()
	t.tween_property(node, "modulate:a", 0.0, DIE_TIME)
	t.tween_property(node, "scale", Vector2(0.6, 0.6), DIE_TIME)
	await t.finished


func _fade_to(alpha: float) -> void:
	var t := _tween()
	t.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await t.finished


## Every sprite must end where the engine says its actor is.
func _check_sync() -> void:
	for a in world.game.level.actors:
		var node := world.actor_node(a.id)
		if node != null and node.position != world.tile_to_px(a.pos):
			push_error("sprite for actor %d desynced: %s vs %s" % [a.id, node.position, world.tile_to_px(a.pos)])
