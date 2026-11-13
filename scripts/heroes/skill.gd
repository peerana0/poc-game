class_name Skill
extends Resource
## One active ability. Numbers live in the hero's .tres file;
## behaviour lives in a subclass that overrides cast().

enum AimType { DIRECTION, POINT }

@export var display_name: String = "Skill"
@export var short_label: String = ""
@export_multiline var description: String = ""
@export var cooldown: float = 8.0
@export var cast_range: float = 8.0
@export var aim_type: AimType = AimType.DIRECTION
## Radius of the target circle shown while aiming a POINT skill.
@export var area_radius: float = 0.0
## Width of the aim line for DIRECTION skills.
@export var line_width: float = 1.0
## When set, POINT skills show a rectangle (across, depth) instead of a circle.
@export var indicator_size: Vector2 = Vector2.ZERO
@export var accent: Color = Color(1.0, 0.5, 0.1)
@export var is_ultimate: bool = false

var cooldown_left: float = 0.0


func is_ready() -> bool:
	return cooldown_left <= 0.0


func tick(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)


func cooldown_ratio(cooldown_scale: float = 1.0) -> float:
	var total := cooldown * cooldown_scale
	if total <= 0.0:
		return 0.0
	return clampf(cooldown_left / total, 0.0, 1.0)


## Override: perform the skill toward target_point (a point on the ground).
func cast(_hero: Hero, _target_point: Vector3) -> void:
	pass
