class_name SkillButton
extends Control
## Round mobile button. Tap a skill to cast at the nearest enemy,
## or drag to aim and release to cast. index -1 is the attack button (hold).

signal pressed_changed(down: bool)
signal aim_started(index: int)
signal aim_changed(index: int, vector: Vector2, finger: Vector2)
signal aim_released(index: int, vector: Vector2, finger: Vector2, dragged: bool)

const AIM_RADIUS := 140.0
const DRAG_THRESHOLD := 18.0

var index := 0
var label_text := ""
var radius := 56.0
var accent := Color(1.0, 0.5, 0.1)
var cooldown_ratio := 0.0
var cooldown_seconds := 0.0

var _touch_index := -1
var _drag := Vector2.ZERO
var _dragged := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func center_global() -> Vector2:
	return global_position + size * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and touch.position.distance_to(center_global()) <= radius * 1.15:
			_touch_index = touch.index
			_drag = Vector2.ZERO
			_dragged = false
			pressed_changed.emit(true)
			if index >= 0:
				aim_started.emit(index)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			pressed_changed.emit(false)
			if index >= 0:
				aim_released.emit(index, _drag / AIM_RADIUS, touch.position, _dragged)
			_drag = Vector2.ZERO
			_dragged = false
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_drag = (drag.position - center_global()).limit_length(AIM_RADIUS)
			if _drag.length() > DRAG_THRESHOLD:
				_dragged = true
			if index >= 0:
				aim_changed.emit(index, _drag / AIM_RADIUS if _dragged else Vector2.ZERO, drag.position)
			queue_redraw()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var c := size * 0.5
	var font := get_theme_default_font()
	var held := _touch_index != -1
	var ready_now := cooldown_ratio <= 0.0
	if held and index >= 0 and _dragged:
		draw_circle(c, AIM_RADIUS, Color(1, 1, 1, 0.06))
		draw_arc(c, AIM_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.3), 2.0, true)
	draw_circle(c, radius, Color(0.04, 0.05, 0.09, 0.7))
	var face := accent.darkened(0.45 if ready_now else 0.75)
	if held:
		face = face.lightened(0.15)
	draw_circle(c, radius - 5.0, Color(face.r, face.g, face.b, 0.95))
	draw_circle(c + Vector2(0.0, -radius * 0.32), radius * 0.55, Color(1, 1, 1, 0.07))
	var rim := accent.lightened(0.35) if ready_now else Color(0.5, 0.5, 0.55)
	draw_arc(c, radius - 2.0, 0.0, TAU, 64, rim, 3.0, true)
	if not ready_now:
		_draw_cooldown(c)
		draw_string(font, Vector2(c.x - radius, c.y + 11.0), str(ceili(cooldown_seconds)), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 30)
	else:
		var font_size := 24 if radius > 70.0 else 19
		draw_string(font, Vector2(c.x - radius, c.y + font_size * 0.35), label_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size)
	if held and index >= 0 and _dragged:
		draw_circle(c + _drag, 22.0, Color(1, 1, 1, 0.7))


func _draw_cooldown(c: Vector2) -> void:
	var sweep := TAU * clampf(cooldown_ratio, 0.0, 1.0)
	if sweep < 0.02:
		return
	var points := PackedVector2Array([c])
	var steps := 40
	for i in steps + 1:
		var angle := -PI * 0.5 + sweep * float(i) / float(steps)
		points.append(c + Vector2(cos(angle), sin(angle)) * (radius - 5.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.55))
