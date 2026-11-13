class_name MobaCamera
extends Camera3D
## Fixed-angle follow camera like mobile MOBAs, with screen shake.
## Screen up is world -Z, screen right is world +X.

@export var follow_offset := Vector3(0.0, 15.0, 9.5)
@export var follow_sharpness := 9.0

var target: Node3D

var _shake_left := 0.0
var _shake_total := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	fov = 42.0
	near = 0.5
	far = 200.0


func snap_to_target() -> void:
	if target == null:
		return
	global_position = target.global_position + follow_offset
	look_at(target.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var desired := target.global_position + follow_offset
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_sharpness * delta))
	if _shake_left > 0.0:
		_shake_left -= delta
		var k := clampf(_shake_left / maxf(_shake_total, 0.001), 0.0, 1.0)
		h_offset = randf_range(-1.0, 1.0) * _shake_strength * k
		v_offset = randf_range(-1.0, 1.0) * _shake_strength * k
	else:
		h_offset = 0.0
		v_offset = 0.0


func shake(strength: float, duration: float) -> void:
	if _shake_left > 0.0:
		strength = maxf(strength, _shake_strength)
	_shake_strength = strength
	_shake_left = maxf(duration, _shake_left)
	_shake_total = _shake_left


## The point on the ground (y = 0) under a screen position.
func ground_point(screen_position: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_position)
	var normal := project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
	if hit == null:
		return Vector3.ZERO
	return hit as Vector3
