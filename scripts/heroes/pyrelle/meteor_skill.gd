class_name MeteorSkill
extends Skill
## Pyrelle ultimate: a warning circle, then a meteor crashes into the area.

@export var damage: float = 480.0
@export var impact_radius: float = 3.5
@export var warning_time: float = 1.0


func cast(hero: Hero, target_point: Vector3) -> void:
	var strike := MeteorStrike.new()
	strike.hero = hero
	strike.skill = self
	strike.position = Vector3(target_point.x, 0.0, target_point.z)
	hero.world().add_child(strike)
