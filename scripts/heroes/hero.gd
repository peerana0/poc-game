class_name Hero
extends Unit
## A playable hero. Players and bots drive it the same way:
## set move_input / attack_held and call try_cast().

signal skill_cast(index: int)

@export var stats: HeroStats
## Keeps the hero inside a circle around the origin (0 = no limit).
@export var arena_radius: float = 0.0

var skills: Array[Skill] = []
var passive: Passive
## x = right, y = down on screen (the camera looks toward -Z).
var move_input := Vector2.ZERO
var attack_held := false
## 1.0 = real cooldowns. The test arena lowers it so skills can be tried quickly.
var cooldown_scale := 1.0
var camera_rig: MobaCamera
var facing := Vector3.FORWARD

var _model: Node3D
var _attack_cooldown := 0.0
var _anim_time := 0.0
var _cast_pulse := 0.0
var _orb_light: OmniLight3D


func _ready() -> void:
	if stats != null:
		max_hp = stats.max_hp
		armor = stats.armor
		move_speed = stats.move_speed
		display_name = stats.display_name
		for entry in stats.skills:
			if entry is Skill:
				skills.append((entry as Skill).duplicate() as Skill)
		if stats.passive is Passive:
			passive = (stats.passive as Passive).duplicate() as Passive
	bar_height = 2.6
	super._ready()
	_model = _make_model()
	add_child(_model)
	_model.rotation.y = atan2(facing.x, facing.z)
	if _model.has_meta("orb_light"):
		_orb_light = _model.get_meta("orb_light") as OmniLight3D
	var ring := Vfx.marker(Color(0.3, 0.85, 1.0, 0.9), 0, 0.07, 0.06, 1.4, Vector2(1.7, 1.7))
	ring.position = Vector3(0.0, 0.04, 0.0)
	add_child(ring)


func _make_model() -> Node3D:
	if stats != null and stats.model_scene != null:
		return stats.model_scene.instantiate() as Node3D
	var hero_id := stats.hero_id if stats != null else ""
	var accent := stats.accent if stats != null else Color.WHITE
	return HeroModels.build(hero_id, accent)


# --- Movement and auto attack ---------------------------------------------

func _unit_physics(delta: float) -> void:
	for skill in skills:
		skill.tick(delta)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if not is_alive():
		velocity = Vector3.ZERO
		return
	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * move_speed * speed_multiplier()
	move_and_slide()
	global_position.y = 0.0
	if arena_radius > 0.0:
		var flat := Vector2(global_position.x, global_position.z)
		if flat.length() > arena_radius:
			flat = flat.normalized() * arena_radius
			global_position = Vector3(flat.x, 0.0, flat.y)
	if dir.length() > 0.1:
		facing = dir.normalized()
	if attack_held:
		_try_basic_attack()


func _try_basic_attack() -> void:
	if _attack_cooldown > 0.0 or stats == null:
		return
	var target := nearest_enemy(stats.attack_range)
	if target == null:
		return
	_attack_cooldown = 1.0 / maxf(stats.attacks_per_second, 0.1)
	facing = flat_dir_to(target.global_position)
	_cast_pulse = maxf(_cast_pulse, 0.5)
	var bolt := Projectile.new()
	bolt.owner_unit = self
	bolt.homing_target = target
	bolt.speed = 22.0
	bolt.max_distance = stats.attack_range + 4.0
	world().add_child(bolt)
	bolt.global_position = cast_origin()
	Vfx.dress_projectile(bolt, stats.accent, 0.45)
	var damage := stats.attack_damage
	bolt.on_hit = func(at: Vector3, hit: Unit) -> void:
		if hit != null and hit.is_alive():
			hit.take_damage(damage, self, "basic")
			if passive != null:
				passive.on_basic_hit(self, hit)
		Vfx.burst(world(), at, Vfx.sparks(0.5))


# --- Skills ---------------------------------------------------------------

## Converts a drag on a skill button (length 0..1) into a ground point.
## A tap (no drag) aims at the nearest enemy.
func skill_target_point(index: int, aim: Vector2) -> Vector3:
	var skill := skills[index]
	if aim.length() < 0.05:
		return auto_target_point(index)
	var dir := Vector3(aim.x, 0.0, aim.y).normalized()
	var reach := skill.cast_range
	if skill.aim_type == Skill.AimType.POINT:
		reach = skill.cast_range * clampf(aim.length(), 0.0, 1.0)
	return global_position + dir * reach


func auto_target_point(index: int) -> Vector3:
	var skill := skills[index]
	var target := nearest_enemy(skill.cast_range + 1.5)
	if target != null:
		return target.global_position
	var reach := skill.cast_range * (0.6 if skill.aim_type == Skill.AimType.POINT else 1.0)
	return global_position + facing * reach


func try_cast(index: int, target_point: Vector3) -> bool:
	if not is_alive() or index < 0 or index >= skills.size():
		return false
	var skill := skills[index]
	if not skill.is_ready():
		return false
	target_point.y = 0.0
	if skill.aim_type == Skill.AimType.POINT:
		var offset := target_point - Vector3(global_position.x, 0.0, global_position.z)
		if offset.length() > skill.cast_range:
			target_point = Vector3(global_position.x, 0.0, global_position.z) + offset.normalized() * skill.cast_range
	facing = flat_dir_to(target_point)
	_model.rotation.y = atan2(facing.x, facing.z)
	skill.cast(self, target_point)
	skill.cooldown_left = skill.cooldown * cooldown_scale
	_cast_pulse = 1.0
	skill_cast.emit(index)
	return true


func notify_skill_hit(target: Unit) -> void:
	if passive != null:
		passive.on_skill_hit(self, target)


# --- Helpers used by skills -----------------------------------------------

func world() -> Node:
	return get_tree().current_scene


func cast_origin() -> Vector3:
	return global_position + Vector3(0.0, 1.3, 0.0) + facing * 0.5


func flat_dir_to(point: Vector3) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return facing
	return d.normalized()


func enemies_in_radius(center: Vector3, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive() or not is_enemy_of(unit):
			continue
		if unit.flat_distance_to(center) <= radius + unit.body_radius:
			result.append(unit)
	return result


func nearest_enemy(max_distance: float) -> Unit:
	var best: Unit = null
	var best_distance := max_distance
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive() or not is_enemy_of(unit):
			continue
		var d := unit.flat_distance_to(global_position) - unit.body_radius
		if d <= best_distance:
			best = unit
			best_distance = d
	return best


func shake_camera(strength: float, duration: float) -> void:
	if camera_rig != null:
		camera_rig.shake(strength, duration)


# --- Procedural animation (until real animated models arrive) ---------------

func _process(delta: float) -> void:
	if _model == null:
		return
	_anim_time += delta
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	var target_yaw := atan2(facing.x, facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
	if moving:
		_model.position.y = absf(sin(_anim_time * 11.0)) * 0.07
	else:
		_model.position.y = sin(_anim_time * 2.6) * 0.025
	_model.rotation.x = lerpf(_model.rotation.x, 0.14 if moving else 0.0, 1.0 - exp(-10.0 * delta))
	_cast_pulse = move_toward(_cast_pulse, 0.0, delta * 3.0)
	_model.scale = Vector3.ONE * (1.0 + 0.1 * _cast_pulse)
	if _orb_light != null:
		_orb_light.light_energy = 1.2 + 3.0 * _cast_pulse + sin(_anim_time * 9.0) * 0.15
