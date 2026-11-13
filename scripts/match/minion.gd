class_name Minion
extends Unit
## Lane soldier. Walks its lane toward the enemy Core and fights the nearest
## enemy it sees. Melee minions swing, ranged minions throw small bolts.

const AGGRO_RANGE := 7.0
const THINK_INTERVAL := 0.25

static var _materials := {}

var ranged := false
var path: PackedVector3Array
var enemy_core: Structure
var attack_range := 1.3
var attack_damage := 24.0
var attack_interval := 1.0

var _waypoint := 0
var _target: Unit
var _think := 0.0
var _cooldown := 0.0
var _model: Node3D
var _time := 0.0
var _lunge := 0.0
var _facing := Vector3.FORWARD


func _ready() -> void:
	body_radius = 0.38
	body_height = 1.1
	bar_height = 1.75
	move_speed = 3.3
	if ranged:
		max_hp = 330.0
		armor = 5.0
		attack_range = 5.0
		attack_damage = 28.0
		attack_interval = 1.2
	else:
		max_hp = 480.0
		armor = 15.0
	super._ready()
	_think = randf() * THINK_INTERVAL
	_model = _build_model()
	add_child(_model)


func _unit_physics(delta: float) -> void:
	if not is_alive():
		velocity = Vector3.ZERO
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_think -= delta
	if _think <= 0.0:
		_think = THINK_INTERVAL
		_target = _find_target()
	var goal: Vector3
	if _target != null and is_instance_valid(_target) and _target.is_alive():
		if flat_distance_to(_target.global_position) <= attack_range + _target.body_radius:
			velocity = Vector3.ZERO
			_face(_target.global_position - global_position)
			if _cooldown <= 0.0:
				_attack(_target)
			return
		goal = _target.global_position
	else:
		goal = _next_waypoint()
	var to_goal := goal - global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.1:
		velocity = Vector3.ZERO
		return
	var dir := to_goal.normalized()
	velocity = dir * move_speed * speed_multiplier()
	_face(dir)
	move_and_slide()
	global_position.y = 0.0


func _next_waypoint() -> Vector3:
	while _waypoint < path.size() and flat_distance_to(path[_waypoint]) < 1.5:
		_waypoint += 1
	if _waypoint < path.size():
		return path[_waypoint]
	if enemy_core != null and enemy_core.is_alive():
		return enemy_core.global_position
	return global_position


func _find_target() -> Unit:
	var best: Unit = null
	var best_distance := AGGRO_RANGE
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or not unit.is_alive() or not is_enemy_of(unit) or unit.is_protected():
			continue
		var d := unit.flat_distance_to(global_position) - unit.body_radius
		if d < best_distance:
			best = unit
			best_distance = d
	return best


func _attack(target: Unit) -> void:
	_cooldown = attack_interval
	_lunge = 1.0
	if not ranged:
		target.take_damage(attack_damage, self, "basic")
		return
	var scene := get_tree().current_scene
	var bolt := Projectile.new()
	bolt.owner_unit = self
	bolt.homing_target = target
	bolt.speed = 16.0
	bolt.max_distance = attack_range + 4.0
	scene.add_child(bolt)
	bolt.global_position = global_position + Vector3(0.0, 1.0, 0.0) + _facing * 0.4
	Vfx.dress_projectile(bolt, TeamPalette.color(team), 0.35, false)
	var damage := attack_damage
	bolt.on_hit = func(_at: Vector3, hit: Unit) -> void:
		if hit != null and hit.is_alive():
			hit.take_damage(damage, self, "basic")


func _face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		_facing = dir.normalized()


func _process(delta: float) -> void:
	if _model == null or not is_alive():
		return
	_time += delta
	_lunge = move_toward(_lunge, 0.0, delta * 4.0)
	var target_yaw := atan2(_facing.x, _facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	_model.position.y = absf(sin(_time * 12.0)) * 0.06 if moving else 0.0
	_model.rotation.x = 0.35 * _lunge


func _on_died() -> void:
	remove_from_group("units")
	var body := get_node("Body") as CollisionShape3D
	body.set_deferred("disabled", true)
	Vfx.burst(get_tree().current_scene, global_position + Vector3(0.0, 0.6, 0.0), Vfx.smoke(0.5))
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.4)
	tween.tween_property(_model, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tween.tween_callback(queue_free)


# --- Model ---------------------------------------------------------------------

static func _team_materials(team_index: int) -> Dictionary:
	if _materials.has(team_index):
		return _materials[team_index]
	var tint := TeamPalette.color(team_index)
	var mats := {
		"cloth": Vfx.surface_material(tint.darkened(0.35)),
		"trim": Vfx.surface_material(tint.lightened(0.1), 0.5, 0.5),
		"metal": Vfx.surface_material(Color(0.7, 0.72, 0.76), 0.35, 0.4),
		"skin": Vfx.surface_material(Color(0.95, 0.78, 0.62), 0.8, 0.2),
		"glow": Vfx.emissive_material(tint.lightened(0.2), 3.0),
	}
	var metal := mats["metal"] as StandardMaterial3D
	metal.metallic = 0.6
	_materials[team_index] = mats
	return mats


func _build_model() -> Node3D:
	var m := _team_materials(team)
	var root := Node3D.new()
	root.add_child(MeshKit.part(MeshKit.cylinder(0.2, 0.3, 0.62, 10), m["cloth"], Vector3(0.0, 0.42, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.2), m["metal"], Vector3(0.0, 0.78, 0.0), Vector3.ZERO, Vector3(1.15, 0.8, 1.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.15), m["skin"], Vector3(0.0, 0.98, 0.03)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.08, 0.17, 0.16, 10), m["metal"], Vector3(0.0, 1.1, 0.0)))
	root.add_child(MeshKit.part(MeshKit.box(Vector3(0.05, 0.16, 0.2)), m["trim"], Vector3(0.0, 1.2, -0.02)))
	if ranged:
		root.add_child(MeshKit.part(MeshKit.cylinder(0.025, 0.025, 1.0, 6), m["metal"], Vector3(0.28, 0.6, 0.12)))
		var orb := MeshKit.part(MeshKit.sphere(0.08), m["glow"], Vector3(0.28, 1.14, 0.12))
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(orb)
	else:
		root.add_child(MeshKit.part(MeshKit.box(Vector3(0.06, 0.6, 0.12)), m["metal"], Vector3(0.3, 0.7, 0.2), Vector3(0.5, 0.0, 0.0)))
		root.add_child(MeshKit.part(MeshKit.cylinder(0.24, 0.24, 0.05, 12), m["trim"], Vector3(-0.3, 0.55, 0.05), Vector3(0.0, 0.0, PI * 0.5)))
	return root
