class_name MatchRules
extends Node
## Win condition and match bookkeeping: kill score, hero respawns, fountain
## healing, team elimination when a Core falls, and the last team standing wins.

signal team_eliminated(team: int)
signal match_over(winner: int)

const RESPAWN_BASE := 6.0
## Extra respawn seconds per minute of match time.
const RESPAWN_PER_MINUTE := 2.0
const FOUNTAIN_HEAL_PER_SECOND := 0.18

var heroes: Array[Hero] = []
var structures: Array[Structure] = []
var kills: Array[int] = [0, 0, 0]
var alive_teams: Array[bool] = [true, true, true]
var winner := -1
var elapsed := 0.0


func register_hero(hero: Hero) -> void:
	heroes.append(hero)
	hero.died.connect(_on_hero_died)


func register_structure(structure: Structure) -> void:
	structures.append(structure)
	if structure.is_core:
		structure.destroyed.connect(_on_core_destroyed)


func is_team_alive(team: int) -> bool:
	return team >= 0 and team < alive_teams.size() and alive_teams[team]


func _physics_process(delta: float) -> void:
	if winner >= 0:
		return
	elapsed += delta
	for hero in heroes:
		if hero.is_alive() and hero.hp < hero.max_hp:
			if hero.flat_distance_to(MapLayout.fountain_position(hero.team)) <= MapLayout.FOUNTAIN_HEAL_RADIUS:
				hero.heal(hero.max_hp * FOUNTAIN_HEAL_PER_SECOND * delta)


func _on_hero_died(unit: Unit) -> void:
	var killer_team := _team_of(unit.last_attacker)
	if killer_team >= 0 and killer_team != unit.team:
		kills[killer_team] += 1
	var hero := unit as Hero
	if hero != null and is_team_alive(hero.team):
		hero.respawn_after(RESPAWN_BASE + elapsed / 60.0 * RESPAWN_PER_MINUTE)


func _on_core_destroyed(core: Structure) -> void:
	var team := core.team
	if not is_team_alive(team):
		return
	alive_teams[team] = false
	for hero in heroes:
		if hero.team == team:
			hero.can_respawn = false
			hero.kill()
	for structure in structures:
		if structure.team == team and structure.is_alive():
			structure.kill()
	team_eliminated.emit(team)
	var remaining: Array[int] = []
	for i in alive_teams.size():
		if alive_teams[i]:
			remaining.append(i)
	if remaining.size() == 1:
		winner = remaining[0]
		match_over.emit(winner)


## Untyped on purpose: the attacker may already be freed (a dead minion).
func _team_of(node) -> int:
	if not is_instance_valid(node):
		return -1
	var unit := node as Unit
	return unit.team if unit != null else -1
