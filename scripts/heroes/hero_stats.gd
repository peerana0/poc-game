class_name HeroStats
extends Resource
## All tunable numbers for one hero. Lives in data/heroes/<id>.tres so
## balance can be changed in the Inspector without touching code.

@export var hero_id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var accent: Color = Color(1.0, 1.0, 1.0)

@export_group("Base stats")
@export var max_hp: float = 2000.0
@export var armor: float = 50.0
@export var move_speed: float = 5.0
@export var attack_damage: float = 70.0
@export var attack_range: float = 7.0
@export var attacks_per_second: float = 0.9

@export_group("Kit")
## A Passive resource (always-on trait).
@export var passive: Resource
## Skill resources in button order: skill 1, skill 2, ultimate.
@export var skills: Array = []

@export_group("Look")
## Optional real model. When empty a placeholder body is built in code.
@export var model_scene: PackedScene
