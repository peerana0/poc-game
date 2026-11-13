class_name Structure
extends Unit
## A defence tower or a team's Core. Shoots the nearest enemy in range,
## minions first, then heroes. A Core can't be damaged while all of its
## team's towers still stand, and losing it eliminates the team.

signal destroyed(structure: Structure)

@export var is_core := false
@export var attack_range := 8.5
@export var attack_damage := 150.0
@export var attack_interval := 1.1

## A Core is protected while every tower in this list is alive.
var guard_towers: Array[Structure] = []

var _cooldown := 0.0
var _target: Unit
var _model: Node3D
var _crystal: Node3D
var _crystal_height := 5.4
var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	body_radius = 1.7 if is_core else 1.1
	body_height = 4.0
	bar_height = 7.4 if is_core else 6.6
	if display_name == "":
		display_name = "Core" if is_core else "ป้อม"
	super._ready()
	collision_layer = 2
	collision_mask = 0
	_model = _build_core() if is_core else _build_tower()
	add_child(_model)


func is_protected() -> bool:
	if not is_core or guard_towers.is_empty():
		return false
	for tower in guard_towers:
		if not tower.is_alive():
			return false
	return true


func _process(delta: float) -> void:
	_time += delta
	if _crystal != null and is_alive():
		_crystal.rotation.y += delta * 0.9
		_crystal.position.y = _crystal_height + sin(_time * 2.0) * 0.15


func _unit_physics(delta: float) -> void:
	if not is_alive():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _pick_target()
	if target == null:
		return
	_cooldown = attack_interval
	_shoot(target)


func _in_range(unit: Unit) -> bool:
	return unit.flat_distance_to(global_position) <= attack_range + unit.body_radius


func _pick_target() -> Unit:
	if _target != null and is_instance_valid(_target) and _target.is_alive() and _in_range(_target):
		return _target
	_target = null
	var best_minion: Unit = null
	var best_hero: Unit = null
	var minion_distance := INF
	var hero_distance := INF
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as Unit
		if unit == null or unit is Structure or not unit.is_alive() or not is_enemy_of(unit):
			continue
		if not _in_range(unit):
			continue
		var d := unit.flat_distance_to(global_position)
		if unit is Hero:
			if d < hero_distance:
				best_hero = unit
				hero_distance = d
		elif d < minion_distance:
			best_minion = unit
			minion_distance = d
	_target = best_minion if best_minion != null else best_hero
	return _target


func _shoot(target: Unit) -> void:
	var scene := get_tree().current_scene
	var bolt := Projectile.new()
	bolt.owner_unit = self
	bolt.homing_target = target
	bolt.speed = 20.0
	bolt.max_distance = attack_range + 8.0
	scene.add_child(bolt)
	bolt.global_position = global_position + Vector3(0.0, _crystal_height, 0.0)
	Vfx.dress_projectile(bolt, TeamPalette.color(team), 1.0)
	# Towers hit heroes harder so diving under them is punished.
	var damage := attack_damage * (1.8 if target is Hero else 1.0)
	bolt.on_hit = func(at: Vector3, hit: Unit) -> void:
		if hit != null and hit.is_alive():
			hit.take_damage(damage, self, "basic")
		Vfx.burst(scene, at, Vfx.sparks(0.6))


func _on_died() -> void:
	destroyed.emit(self)
	var scene := get_tree().current_scene
	var center := global_position
	Vfx.burst(scene, center + Vector3(0.0, 2.0, 0.0), Vfx.explosion(2.0))
	Vfx.burst(scene, center + Vector3(0.0, 1.5, 0.0), Vfx.smoke(2.5))
	Vfx.shockwave(scene, center, TeamPalette.color(team), 7.0, 0.7)
	Vfx.flash(scene, center + Vector3(0.0, 3.0, 0.0), TeamPalette.color(team), 6.0, 14.0, 0.6)
	var body := get_node("Body") as CollisionShape3D
	body.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_model, "position:y", -2.6, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_model, "rotation:z", 0.25, 1.2)
	if _light != null:
		tween.tween_property(_light, "light_energy", 0.0, 0.8)
	if _crystal != null:
		tween.tween_property(_crystal, "scale", Vector3.ZERO, 0.5)


# --- Models ------------------------------------------------------------------

func _build_tower() -> Node3D:
	var root := Node3D.new()
	var tint := TeamPalette.color(team)
	var stone := Vfx.surface_material(Color(0.66, 0.64, 0.6), 0.85, 0.2)
	var dark := Vfx.surface_material(Color(0.3, 0.29, 0.32), 0.9, 0.15)
	var trim := Vfx.surface_material(tint.darkened(0.25), 0.4, 0.5)
	trim.metallic = 0.4
	root.add_child(MeshKit.part(MeshKit.cylinder(1.3, 1.5, 0.6, 8), dark, Vector3(0.0, 0.3, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.8, 1.05, 3.4, 8), stone, Vector3(0.0, 2.3, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.95, 0.95, 0.25, 8), trim, Vector3(0.0, 1.5, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(1.2, 0.9, 0.55, 8), trim, Vector3(0.0, 4.25, 0.0)))
	for i in 4:
		var angle := PI * 0.25 + float(i) * PI * 0.5
		root.add_child(MeshKit.part(MeshKit.cylinder(0.0, 0.2, 1.1, 5), trim, Vector3(cos(angle) * 0.9, 5.0, sin(angle) * 0.9)))
	_crystal_height = 5.6
	_crystal = _make_crystal(0.55, tint)
	_crystal.position.y = _crystal_height
	root.add_child(_crystal)
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 1.6
	_light.omni_range = 7.0
	_light.position.y = _crystal_height
	root.add_child(_light)
	return root


func _build_core() -> Node3D:
	var root := Node3D.new()
	var tint := TeamPalette.color(team)
	var stone := Vfx.surface_material(Color(0.7, 0.68, 0.64), 0.85, 0.2)
	var dark := Vfx.surface_material(Color(0.28, 0.27, 0.3), 0.9, 0.15)
	var trim := Vfx.surface_material(tint.darkened(0.2), 0.35, 0.5)
	trim.metallic = 0.5
	root.add_child(MeshKit.part(MeshKit.cylinder(2.6, 3.0, 0.5, 10), dark, Vector3(0.0, 0.25, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(2.1, 2.5, 0.6, 10), stone, Vector3(0.0, 0.8, 0.0)))
	root.add_child(MeshKit.part(MeshKit.torus(2.0, 2.3), trim, Vector3(0.0, 1.12, 0.0)))
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var spot := Vector3(cos(angle) * 2.2, 0.0, sin(angle) * 2.2)
		root.add_child(MeshKit.part(MeshKit.cylinder(0.0, 0.3, 2.6, 5), trim, spot + Vector3(0.0, 2.2, 0.0), Vector3(-0.25 * spot.z / 2.2, 0.0, 0.25 * spot.x / 2.2)))
	_crystal_height = 4.4
	_crystal = _make_crystal(1.3, tint)
	_crystal.position.y = _crystal_height
	root.add_child(_crystal)
	var ring := MeshKit.part(MeshKit.torus(1.9, 2.0), Vfx.emissive_material(tint, 2.5), Vector3(0.0, _crystal_height, 0.0), Vector3(0.4, 0.0, 0.0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal.add_child(ring)
	ring.position = Vector3.ZERO
	var motes := Vfx.particles({
		"amount": 30, "lifetime": 2.0, "radius": 1.8, "spread": 20.0,
		"vel_min": 0.4, "vel_max": 1.0, "size": 0.22,
		"colors": Vfx.trail_colors(tint),
	})
	motes.position.y = 1.5
	root.add_child(motes)
	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.light_energy = 2.4
	_light.omni_range = 12.0
	_light.position.y = _crystal_height
	root.add_child(_light)
	return root


func _make_crystal(crystal_size: float, tint: Color) -> Node3D:
	var crystal := Node3D.new()
	var glow := Vfx.emissive_material(tint.lightened(0.15), 3.0)
	var top := MeshKit.part(MeshKit.cylinder(0.0, crystal_size, crystal_size * 1.5, 6), glow, Vector3(0.0, crystal_size * 0.75, 0.0))
	var bottom := MeshKit.part(MeshKit.cylinder(crystal_size, 0.0, crystal_size * 1.0, 6), glow, Vector3(0.0, -crystal_size * 0.5, 0.0))
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crystal.add_child(top)
	crystal.add_child(bottom)
	return crystal
