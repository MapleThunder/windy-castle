class_name ItemSlot
extends Button
## One cell in the inventory panel: an equipment slot, a pack item or an item on the floor.

const SIZE := Vector2(44, 44)

var panel: Node  # InventoryPanel
var area := ""  # "equip", "pack" or "floor"
var slot := ""  # equipment slot name (area "equip")
var item: Dictionary = {}  # empty for an empty equipment slot or the pack's drop target


func _init() -> void:
	custom_minimum_size = SIZE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_ALL


func _get_drag_data(_at: Vector2) -> Variant:
	if item.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.custom_minimum_size = SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return self


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is ItemSlot and data != self


func _drop_data(_at: Vector2, data: Variant) -> void:
	panel.move(data, self)
