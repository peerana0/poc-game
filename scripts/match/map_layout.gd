class_name MapLayout
extends RefCounted
## Geometry of the three-team map. Bases sit on a triangle around the centre
## (team 0 at the bottom of the screen). Each lane joins two neighbouring Cores
## and bows outward, leaving jungle between the lanes and the World Boss pit
## in the middle.

const TEAM_COUNT := 3
const FOUNTAIN_RADIUS := 47.0
const CORE_RADIUS := 39.0
const PLAY_RADIUS := 56.0
const LANE_BULGE := 9.0
const LANE_SAMPLES := 18
const LANE_WIDTH := 6.0
const BOSS_PIT_RADIUS := 8.0
## Heroes standing this close to their own fountain heal quickly.
const FOUNTAIN_HEAL_RADIUS := 6.0


static func base_angle(team: int) -> float:
	return TAU * float(team) / float(TEAM_COUNT)


static func on_circle(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)


static func fountain_position(team: int) -> Vector3:
	return on_circle(base_angle(team), FOUNTAIN_RADIUS)


static func core_position(team: int) -> Vector3:
	return on_circle(base_angle(team), CORE_RADIUS)


## Lane k joins team k and team k + 1.
static func lane_teams(lane: int) -> Vector2i:
	return Vector2i(lane, (lane + 1) % TEAM_COUNT)


## Points from the first team's Core to the second team's Core.
static func lane_points(lane: int) -> PackedVector3Array:
	var teams := lane_teams(lane)
	var a := core_position(teams.x)
	var b := core_position(teams.y)
	var dir := (b - a).normalized()
	var start := a + dir * 4.0
	var end := b - dir * 4.0
	var mid := (start + end) * 0.5
	var outward := Vector3(mid.x, 0.0, mid.z).normalized()
	var control := mid + outward * LANE_BULGE * 2.0
	var points := PackedVector3Array()
	for i in LANE_SAMPLES + 1:
		var t := float(i) / float(LANE_SAMPLES)
		var u := 1.0 - t
		points.append(start * (u * u) + control * (2.0 * u * t) + end * (t * t))
	return points


## The lane as walked by one of its two teams (from its own Core outward).
static func lane_path(lane: int, team: int) -> PackedVector3Array:
	var points := lane_points(lane)
	if lane_teams(lane).y == team:
		points.reverse()
	return points


static func lanes_of_team(team: int) -> Array[int]:
	var result: Array[int] = []
	for lane in TEAM_COUNT:
		var teams := lane_teams(lane)
		if teams.x == team or teams.y == team:
			result.append(lane)
	return result


static func enemy_on_lane(lane: int, team: int) -> int:
	var teams := lane_teams(lane)
	return teams.y if teams.x == team else teams.x


## A point part of the way along a path (t = 0..1, by sample index).
static func point_along(path: PackedVector3Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(path.size() - 1)
	var i := mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - float(i))


static func distance_to_lanes(point: Vector3) -> float:
	var best := INF
	var p := Vector2(point.x, point.z)
	for lane in TEAM_COUNT:
		var points := lane_points(lane)
		for i in points.size() - 1:
			var a := Vector2(points[i].x, points[i].z)
			var b := Vector2(points[i + 1].x, points[i + 1].z)
			var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
			best = minf(best, p.distance_to(closest))
	return best
