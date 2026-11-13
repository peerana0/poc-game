class_name VirtualJoystick
extends Control
## Floating thumbstick: put a thumb anywhere in this area and drag to move.
## Handles its own touch index so it works alongside the skill buttons.

signal changed(value: Vector2)

@export var radius := 105.0
@export var knob_radius := 44.0
@export var dead_zone := 0.12

var value := Vector2.ZERO

var _touch_index := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rest_position() -> Vector2:
	return Vector2(radius + 40.0, size.y - radius - 40.0)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_base = touch.position - global_position
			_base.x = clampf(_base.x, radius, maxf(size.x - radius, radius))
			_base.y = clampf(_base.y, radius, maxf(size.y - radius, radius))
			_drag_to(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_drag_to(drag.position)
			get_viewport().set_input_as_handled()


func _drag_to(screen_position: Vector2) -> void:
	_knob = (screen_position - global_position - _base).limit_length(radius)
	var v := _knob / radius
	value = v if v.length() > dead_zone else Vector2.ZERO
	changed.emit(value)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob = Vector2.ZERO
	value = Vector2.ZERO
	changed.emit(value)
	queue_redraw()


func _draw() -> void:
	var active := _touch_index != -1
	var center := _base if active else _rest_position()
	draw_circle(center, radius, Color(0.05, 0.07, 0.12, 0.38 if active else 0.22))
	draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.5 if active else 0.25), 3.0, true)
	draw_circle(center + _knob, knob_radius, Color(1, 1, 1, 0.6 if active else 0.35))
	draw_arc(center + _knob, knob_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 2.0, true)
