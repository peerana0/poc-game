class_name Projectile
extends Node3D
## Flies straight (skill shots) or homes on a target (basic attacks)
## and calls on_hit(position, hit_unit_or_null) exactly once.

var owner_unit: Unit
var direction := Vector3.FORWARD
var speed := 18.0
var max_distance := 10.0
var hit_radius := 0.5
var homing_target: Unit
var on_hit: Callable

var _travelled := 0.0
var _done := false


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := speed * delta
	if homing_target != null:
		if not is_instance_valid(homing_target) or not homing_target.is_alive():
			_finish(null)
			return
		var aim_point := homing_target.global_position + Vector3(0.0, homing_target.body_height * 0.6, 0.0)
		var to_target := aim_point - global_position
		if to_target.length() <= step + 0.2:
			global_position = aim_point
			_finish(homing_target)
			return
		direction = to_target.normalized()
		global_position += direction * step
		_travelled += step
	else:
		global_position += direction * step
		_travelled += step
		var hit := _first_enemy_hit()
		if hit != null:
			_finish(hit)
			return
	if _travelled >= max_distance:
		_finish(null)


func _first_enemy_hit() -> Unit:
	if owner_unit == null:
		return null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive() or not owner_unit.is_enemy_of(unit):
			continue
		if unit.flat_distance_to(global_position) <= hit_radius + unit.body_radius:
			return unit
	return null


func _finish(hit: Unit) -> void:
	_done = true
	if on_hit.is_valid():
		on_hit.call(global_position, hit)
	# Let the trail fade out instead of vanishing.
	for child in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false
		elif child is VisualInstance3D:
			(child as VisualInstance3D).visible = false
	get_tree().create_timer(0.8).timeout.connect(queue_free)
