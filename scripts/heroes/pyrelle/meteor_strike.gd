class_name MeteorStrike
extends Node3D
## Warning circle, falling meteor and impact for MeteorSkill.

const FALL_TIME := 0.55
const START_OFFSET := Vector3(-4.0, 22.0, -6.0)

var hero: Hero
var skill: MeteorSkill

var _warning: MeshInstance3D
var _rock: Node3D
var _age := 0.0
var _impacted := false


func _ready() -> void:
	var radius := skill.impact_radius
	_warning = Vfx.marker(Color(1.0, 0.3, 0.05, 1.0), 0, 0.04, 0.18, 2.0)
	_warning.scale = Vector3(radius, 1.0, radius)
	_warning.position.y = 0.05
	add_child(_warning)
	var material := _warning.material_override as ShaderMaterial
	material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, skill.warning_time)
	_rock = _make_rock()
	_rock.position = START_OFFSET
	_rock.visible = false
	add_child(_rock)


func _make_rock() -> Node3D:
	var rock := Node3D.new()
	var core := MeshKit.part(MeshKit.sphere(0.75), Vfx.emissive_material(Color(1.0, 0.4, 0.08), 5.0), Vector3.ZERO)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock.add_child(core)
	rock.add_child(Vfx.particles({
		"amount": 90, "lifetime": 0.6, "radius": 0.6, "spread": 180.0,
		"vel_min": 0.2, "vel_max": 1.0, "gravity": Vector3(0, 2.0, 0), "size": 1.6,
		"colors": Vfx.fire_colors(),
	}))
	rock.add_child(Vfx.particles({
		"amount": 30, "lifetime": 1.0, "radius": 0.5, "spread": 180.0,
		"vel_min": 0.1, "vel_max": 0.5, "size": 1.8, "additive": false,
		"colors": [Color(0.3, 0.25, 0.2, 0.0), Color(0.2, 0.17, 0.15, 0.5), Color(0.1, 0.1, 0.1, 0.0)],
	}))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.1)
	light.light_energy = 4.0
	light.omni_range = 8.0
	rock.add_child(light)
	return rock


func _physics_process(delta: float) -> void:
	if _impacted:
		return
	_age += delta
	var fall_start := skill.warning_time - FALL_TIME
	if _age >= fall_start:
		_rock.visible = true
		var t := clampf((_age - fall_start) / FALL_TIME, 0.0, 1.0)
		_rock.position = START_OFFSET.lerp(Vector3(0.0, 0.6, 0.0), t * t)
	if _age >= skill.warning_time:
		_impact()


func _impact() -> void:
	_impacted = true
	_rock.queue_free()
	var world := hero.world()
	var center := global_position
	for enemy in hero.enemies_in_radius(center, skill.impact_radius):
		enemy.take_damage(skill.damage, hero)
		hero.notify_skill_hit(enemy)
	PyrelleFx.explosion(world, center, 2.2)
	Vfx.shockwave(world, center, Color(1.0, 0.55, 0.15, 1.0), skill.impact_radius * 1.6, 0.6)
	hero.shake_camera(0.45, 0.45)
	# The ground keeps smouldering for a moment.
	var embers := Vfx.embers(skill.impact_radius * 0.8)
	embers.position.y = 0.1
	add_child(embers)
	var material := _warning.material_override as ShaderMaterial
	material.set_shader_parameter("color", Color(0.9, 0.2, 0.02, 1.0))
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void: embers.emitting = false)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("alpha", value), 1.0, 0.0, 0.8)
	tween.tween_callback(queue_free)
