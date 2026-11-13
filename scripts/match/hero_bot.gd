class_name HeroBot
extends Node
## Plays a Hero the way a player would: pushes its lane behind the minions,
## fights enemy heroes with skills, avoids enemy towers without minion cover,
## and walks back to the fountain to heal when low.

const THINK_INTERVAL := 0.2
const SIGHT := 10.0

var hero: Hero
var rules: MatchRules
var lane := 0
var path: PackedVector3Array

var _think := 0.0
var _retreating := false
var _goal := Vector3.ZERO


func setup(p_hero: Hero, p_lane: int, p_rules: MatchRules) -> void:
	hero = p_hero
	rules = p_rules
	lane = p_lane
	path = MapLayout.lane_path(lane, hero.team)
	_think = randf() * THINK_INTERVAL
	_goal = hero.global_position


func _physics_process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if not hero.is_alive():
		hero.move_input = Vector2.ZERO
		hero.attack_held = false
		_retreating = false
		_goal = hero.home_position
		return
	_think -= delta
	if _think <= 0.0:
		_think = THINK_INTERVAL
		_decide()
	_steer()


func _decide() -> void:
	if hero.hp_ratio() < 0.3:
		_retreating = true
	if _retreating:
		if hero.hp_ratio() > 0.92:
			_retreating = false
		else:
			hero.attack_held = false
			_goal = hero.home_position
			return

	var enemy_hero := _nearest_enemy_hero(SIGHT)
	if enemy_hero != null and _tower_threat(enemy_hero.global_position) == null:
		_fight_hero(enemy_hero)
		return

	var target := hero.nearest_enemy(SIGHT)
	if target != null and _safe_to_hit(target):
		hero.attack_held = true
		_use_wave_skill(target)
		_approach(target, hero.stats.attack_range * 0.9)
		return

	hero.attack_held = false
	_goal = _lane_goal()


func _steer() -> void:
	var to_goal := _goal - hero.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.6:
		hero.move_input = Vector2.ZERO
		return
	var dir := to_goal.normalized()
	hero.move_input = Vector2(dir.x, dir.z)


# --- Fighting ----------------------------------------------------------------

func _fight_hero(enemy: Unit) -> void:
	hero.attack_held = true
	var distance := hero.flat_distance_to(enemy.global_position)
	for i in hero.skills.size():
		var skill := hero.skills[i]
		if not skill.is_ready() or distance > skill.cast_range + 0.5:
			continue
		# Save the ultimate for a low enemy or a group.
		if skill.is_ultimate and enemy.hp_ratio() > 0.55 and _enemy_heroes_near(enemy.global_position, 3.5) < 2:
			continue
		var lead := enemy.velocity * 0.35
		hero.try_cast(i, enemy.global_position + Vector3(lead.x, 0.0, lead.z))
		break
	_approach(enemy, hero.stats.attack_range * 0.85)


## Fireball a clump of minions to clear the wave faster.
func _use_wave_skill(target: Unit) -> void:
	if hero.skills.is_empty() or target is Hero or target is Structure:
		return
	var skill := hero.skills[0]
	if not skill.is_ready() or hero.flat_distance_to(target.global_position) > skill.cast_range:
		return
	var clump := 0
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit is Minion and unit.is_alive() and hero.is_enemy_of(unit) and unit.flat_distance_to(target.global_position) < 2.5:
			clump += 1
	if clump >= 3:
		hero.try_cast(0, target.global_position)


## Stays about `distance` away from the target: closes in, holds, or backs off.
func _approach(target: Unit, distance: float) -> void:
	var offset := target.global_position - hero.global_position
	offset.y = 0.0
	var current := offset.length()
	if current > distance:
		_goal = target.global_position
	elif current < distance * 0.55 and current > 0.01:
		_goal = hero.global_position - offset.normalized() * 2.0
	else:
		_goal = hero.global_position


# --- Awareness ---------------------------------------------------------------

func _nearest_enemy_hero(max_distance: float) -> Unit:
	var best: Unit = null
	var best_distance := max_distance
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if not (unit is Hero) or not unit.is_alive() or not hero.is_enemy_of(unit):
			continue
		var d := unit.flat_distance_to(hero.global_position)
		if d < best_distance:
			best = unit
			best_distance = d
	return best


func _enemy_heroes_near(center: Vector3, radius: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit is Hero and unit.is_alive() and hero.is_enemy_of(unit) and unit.flat_distance_to(center) <= radius:
			count += 1
	return count


## An enemy structure that would shoot us at `point` because no allied
## minions are there to take the hits.
func _tower_threat(point: Vector3) -> Structure:
	for node in get_tree().get_nodes_in_group("units"):
		var structure := node as Structure
		if structure == null or not structure.is_alive() or not hero.is_enemy_of(structure):
			continue
		if structure.flat_distance_to(point) > structure.attack_range + 1.5:
			continue
		if _allied_minions_near(structure.global_position, structure.attack_range) < 2:
			return structure
	return null


func _allied_minions_near(center: Vector3, radius: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit is Minion and unit.is_alive() and unit.team == hero.team and unit.flat_distance_to(center) <= radius:
			count += 1
	return count


func _safe_to_hit(target: Unit) -> bool:
	if target.is_protected():
		return false
	return _tower_threat(target.global_position) == null and _tower_threat(hero.global_position) == null


## Walks up the lane, stopping short of enemy towers that have no minions under them.
func _lane_goal() -> Vector3:
	# Once the team at the far end of this lane is gone, push the other lane.
	if rules != null and not rules.is_team_alive(MapLayout.enemy_on_lane(lane, hero.team)):
		for other in MapLayout.lanes_of_team(hero.team):
			if other != lane and rules.is_team_alive(MapLayout.enemy_on_lane(other, hero.team)):
				lane = other
				path = MapLayout.lane_path(lane, hero.team)
				break
	var nearest := 0
	var nearest_distance := INF
	for i in path.size():
		var d := hero.flat_distance_to(path[i])
		if d < nearest_distance:
			nearest = i
			nearest_distance = d
	if _tower_threat(hero.global_position) != null:
		return path[maxi(nearest - 3, 0)]
	var ahead := mini(nearest + 2, path.size() - 1)
	if _tower_threat(path[ahead]) != null:
		return hero.global_position
	if nearest >= path.size() - 1:
		var enemy_core := MapLayout.core_position(MapLayout.enemy_on_lane(lane, hero.team))
		if _tower_threat(enemy_core) == null:
			return enemy_core
	return path[ahead]
