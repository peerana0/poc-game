class_name AimIndicator
extends Node3D
## Ground markers shown while the player drags a skill button:
## the skill's range ring plus a line, circle or wall shape at the target.

var _range_ring: MeshInstance3D
var _shape_rect: MeshInstance3D
var _shape_circle: MeshInstance3D


func _ready() -> void:
	_range_ring = Vfx.marker(Color(1.0, 1.0, 1.0, 0.55), 0, 0.015, 0.04, 1.0)
	_shape_rect = Vfx.marker(Color(1.0, 0.6, 0.2, 0.9), 1, 0.06, 0.28, 1.6, Vector2(1.0, 1.0))
	_shape_circle = Vfx.marker(Color(1.0, 0.6, 0.2, 0.9), 0, 0.05, 0.25, 1.6)
	for mesh: MeshInstance3D in [_range_ring, _shape_rect, _shape_circle]:
		mesh.position.y = 0.05
		add_child(mesh)
	hide_all()


func show_aim(hero: Hero, skill: Skill, target_point: Vector3) -> void:
	visible = true
	global_position = Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	_range_ring.scale = Vector3(skill.cast_range, 1.0, skill.cast_range)
	var offset := target_point - global_position
	offset.y = 0.0
	var dir := offset.normalized() if offset.length() > 0.05 else hero.facing
	var yaw := atan2(dir.x, dir.z)

	if skill.aim_type == Skill.AimType.DIRECTION:
		_show_rect(Vector3(dir.x, 0.0, dir.z) * skill.cast_range * 0.5, yaw, Vector2(skill.line_width, skill.cast_range), skill.accent)
	elif skill.indicator_size != Vector2.ZERO:
		_show_rect(offset, yaw, skill.indicator_size, skill.accent)
	else:
		_shape_rect.visible = false
		_shape_circle.visible = true
		var radius := maxf(skill.area_radius, 0.8)
		_shape_circle.position = Vector3(offset.x, 0.05, offset.z)
		_shape_circle.scale = Vector3(radius, 1.0, radius)
		_set_color(_shape_circle, skill.accent)


func hide_all() -> void:
	visible = false


## size.x runs across the aim direction, size.y along it.
func _show_rect(center: Vector3, yaw: float, size: Vector2, color: Color) -> void:
	_shape_circle.visible = false
	_shape_rect.visible = true
	_shape_rect.position = Vector3(center.x, 0.05, center.z)
	_shape_rect.rotation = Vector3(0.0, yaw, 0.0)
	_shape_rect.scale = Vector3(size.x, 1.0, size.y)
	_set_color(_shape_rect, color)


func _set_color(mesh: MeshInstance3D, color: Color) -> void:
	var material := mesh.material_override as ShaderMaterial
	material.set_shader_parameter("color", Color(color.r, color.g, color.b, 0.9))
