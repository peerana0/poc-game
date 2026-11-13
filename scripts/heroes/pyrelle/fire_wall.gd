class_name FireWall
extends Node3D
## The lingering wall placed by FireWallSkill. It spans the local X axis.

var hero: Hero
var skill: FireWallSkill

var _age := 0.0
var _tick := 0.0
var _flames: GPUParticles3D
var _scorch: MeshInstance3D
var _light: OmniLight3D
var _ending := false


func _ready() -> void:
	var half := skill.wall_length * 0.5
	_scorch = Vfx.marker(Color(1.0, 0.35, 0.05, 0.9), 1, 0.08, 0.35, 2.2, Vector2(skill.wall_length, 1.2))
	_scorch.position.y = 0.05
	add_child(_scorch)
	_flames = Vfx.wall_flames(half)
	_flames.position.y = 0.1
	add_child(_flames)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.12)
	_light.light_energy = 2.5
	_light.omni_range = maxf(skill.wall_length, 4.0)
	_light.position.y = 1.0
	add_child(_light)
	# Grow out sideways from the centre.
	scale = Vector3(0.1, 1.0, 1.0)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.burst(hero.world(), position + Vector3(0.0, 0.5, 0.0), Vfx.sparks(1.0))
	Vfx.flash(hero.world(), position + Vector3(0.0, 1.0, 0.0), Color(1.0, 0.45, 0.12), 4.0, 6.0, 0.3)


func _physics_process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	_tick += delta
	if _tick >= skill.tick_interval:
		_tick -= skill.tick_interval
		_damage_tick()
	_light.light_energy = 2.2 + sin(_age * 17.0) * 0.4
	if _age >= skill.duration:
		_end()


func _damage_tick() -> void:
	var half := skill.wall_length * 0.5
	var to_local := global_transform.affine_inverse()
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive() or not hero.is_enemy_of(unit):
			continue
		var local := to_local * unit.global_position
		if absf(local.x) <= half + unit.body_radius and absf(local.z) <= 0.6 + unit.body_radius:
			unit.take_damage(skill.tick_damage, hero, "skill")
			unit.apply_slow(skill.slow_multiplier, skill.tick_interval + 0.2)
			hero.notify_skill_hit(unit)


func _end() -> void:
	_ending = true
	_flames.emitting = false
	var material := _scorch.material_override as ShaderMaterial
	var tween := create_tween().set_parallel(true)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("alpha", value), 1.0, 0.0, 0.8)
	tween.tween_property(_light, "light_energy", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)
