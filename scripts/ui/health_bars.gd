class_name HealthBars
extends Control
## Draws HP bars over every unit by projecting their 3D positions.
## A light "damage trail" lags behind so big hits read clearly.

const SEGMENT_HP := 500.0

var camera: Camera3D
var local_team := 0
var local_hero: Unit

var _lag := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var font := get_theme_default_font()
	var delta := get_process_delta_time()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive():
			continue
		var world_point := unit.global_position + Vector3(0.0, unit.bar_height, 0.0)
		if camera.is_position_behind(world_point):
			continue
		var p := camera.unproject_position(world_point)
		var is_hero := unit is Hero
		var width := 84.0
		var height := 10.0
		if is_hero:
			width = 112.0
			height = 13.0
		elif unit is Structure:
			width = 140.0
			height = 14.0
		elif unit is Minion:
			width = 46.0
			height = 6.0
		var rect := Rect2(p - Vector2(width * 0.5, height), Vector2(width, height))
		var ratio := unit.hp_ratio()
		var key := unit.get_instance_id()
		var lag: float = _lag.get(key, ratio)
		lag = maxf(ratio, lag - delta * 0.6) if lag > ratio else ratio
		_lag[key] = lag

		var fill := Color(0.35, 0.9, 0.4)
		if unit != local_hero:
			fill = Color(0.3, 0.75, 1.0) if unit.team == local_team else TeamPalette.color(unit.team)
		if unit.is_protected():
			fill = fill.lerp(Color(0.6, 0.6, 0.65), 0.6)
		draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(rect.position, Vector2(width * lag, height)), Color(1.0, 0.95, 0.8, 0.9))
		draw_rect(Rect2(rect.position, Vector2(width * ratio, height)), fill)
		var ticks := int(unit.max_hp / SEGMENT_HP) if is_hero else 0
		for i in range(1, ticks + 1):
			var x := rect.position.x + width * (float(i) * SEGMENT_HP / unit.max_hp)
			if x < rect.end.x - 1.0:
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0, 0, 0, 0.55), 1.0)
		if unit.is_burning():
			draw_circle(Vector2(rect.end.x + 9.0, rect.position.y + height * 0.5), 5.0, Color(1.0, 0.5, 0.1))
		if unit.display_name != "":
			draw_string(font, Vector2(rect.position.x, rect.position.y - 6.0), unit.display_name, HORIZONTAL_ALIGNMENT_CENTER, width, 15 if is_hero else 12)
