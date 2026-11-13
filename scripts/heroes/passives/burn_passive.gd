class_name BurnPassive
extends Passive
## Pyrelle: every skill hit sets the target on fire for a share of its max HP.

@export var percent_max_hp: float = 0.03
@export var duration: float = 3.0


func on_skill_hit(hero: Hero, target: Unit) -> void:
	if target != null and target.is_alive():
		target.apply_burn(target.max_hp * percent_max_hp, duration, hero)
