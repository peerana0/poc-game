class_name Minimap
extends Control
## Round map in the corner: lanes, bases, towers, heroes and minions.

const WORLD_RADIUS := 60.0

var local_hero: Hero

var _lanes: Array[PackedVector3Array] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lane in MapLayout.TEAM_COUNT:
		_lanes.append(MapLayout.lane_points(lane))


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(point: Vector3) -> Vector2:
	var half := size * 0.5
	return half + Vector2(point.x, point.z) / WORLD_RADIUS * half.x


func _draw() -> void:
	var half := size * 0.5
	draw_circle(half, half.x, Color(0.04, 0.09, 0.06, 0.78))
	draw_circle(half, MapLayout.BOSS_PIT_RADIUS / WORLD_RADIUS * half.x, Color(0.5, 0.3, 0.8, 0.35))
	for lane_points in _lanes:
		var points := PackedVector2Array()
		for point in lane_points:
			points.append(_to_map(point))
		draw_polyline(points, Color(0.82, 0.7, 0.5, 0.75), 4.0, true)
	for team in MapLayout.TEAM_COUNT:
		var base := _to_map(MapLayout.fountain_position(team))
		draw_circle(base, 9.0, Color(TeamPalette.color(team), 0.35))
	draw_arc(half, half.x - 1.0, 0.0, TAU, 64, Color(1, 1, 1, 0.4), 2.0, true)

	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive():
			continue
		var p := _to_map(unit.global_position)
		var tint := TeamPalette.color(unit.team)
		if unit is Structure:
			var s := 7.0 if (unit as Structure).is_core else 5.0
			draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(p - Vector2(s - 1.5, s - 1.5), Vector2(s - 1.5, s - 1.5) * 2.0), tint)
		elif unit is Hero:
			if unit == local_hero:
				draw_circle(p, 7.5, Color(1, 1, 1))
			else:
				draw_circle(p, 6.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 5.0, tint)
		else:
			draw_circle(p, 2.0, tint)
