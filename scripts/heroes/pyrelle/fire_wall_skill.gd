class_name FireWallSkill
extends Skill
## Pyrelle skill 2: a wall of fire across the aim direction.
## Enemies standing in it are slowed and burned.

@export var wall_length: float = 6.0
@export var duration: float = 4.0
@export var tick_damage: float = 40.0
@export var tick_interval: float = 0.5
## Speed multiplier while inside the wall (0.7 = 30% slower).
@export var slow_multiplier: float = 0.7


func cast(hero: Hero, target_point: Vector3) -> void:
	var dir := hero.flat_dir_to(target_point)
	var wall := FireWall.new()
	wall.hero = hero
	wall.skill = self
	wall.position = Vector3(target_point.x, 0.0, target_point.z)
	wall.rotation.y = atan2(dir.x, dir.z)
	hero.world().add_child(wall)
