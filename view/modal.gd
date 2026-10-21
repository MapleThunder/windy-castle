class_name Modal
extends RefCounted
## Wrap a panel in a full-screen dimmed backdrop that centres it.


static func wrap(panel: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(dim)
	center.add_child(panel)
	return center
