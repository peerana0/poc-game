class_name Passive
extends Resource
## Always-on hero trait. Hero calls these hooks; subclasses override them.

@export var display_name: String = ""
@export_multiline var description: String = ""


func on_skill_hit(_hero: Hero, _target: Unit) -> void:
	pass


func on_basic_hit(_hero: Hero, _target: Unit) -> void:
	pass
