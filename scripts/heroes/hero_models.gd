class_name HeroModels
extends RefCounted
## Placeholder hero bodies built from simple shapes, facing +Z.
## Set HeroStats.model_scene to swap in a real rigged model later.


static func build(hero_id: String, accent: Color) -> Node3D:
	match hero_id:
		"pyrelle":
			return _pyrelle()
		_:
			return _generic(accent)


static func _generic(accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := Vfx.surface_material(accent.darkened(0.3))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.3, 0.4, 1.2), body, Vector3(0.0, 0.6, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.22), Vfx.surface_material(Color(0.95, 0.8, 0.68)), Vector3(0.0, 1.45, 0.0)))
	return root


## Pyrelle, fire mage: crimson robe, wizard hat, burning hair and a staff with a fire orb.
static func _pyrelle() -> Node3D:
	var root := Node3D.new()
	var robe := Vfx.surface_material(Color(0.62, 0.09, 0.1))
	var robe_dark := Vfx.surface_material(Color(0.32, 0.04, 0.06))
	var gold := Vfx.surface_material(Color(1.0, 0.76, 0.3), 0.35, 0.5)
	gold.metallic = 0.8
	var skin := Vfx.surface_material(Color(0.98, 0.82, 0.7), 0.8, 0.25)
	var hair := Vfx.emissive_material(Color(1.0, 0.38, 0.08), 0.6)
	var wood := Vfx.surface_material(Color(0.3, 0.18, 0.1))
	var ember := Vfx.emissive_material(Color(1.0, 0.55, 0.15), 5.0)

	# Robe, cape and body
	root.add_child(MeshKit.part(MeshKit.cylinder(0.2, 0.5, 1.05, 20), robe, Vector3(0.0, 0.525, 0.0)))
	root.add_child(MeshKit.part(MeshKit.torus(0.44, 0.52), gold, Vector3(0.0, 0.05, 0.0)))
	root.add_child(MeshKit.part(MeshKit.box(Vector3(0.5, 0.95, 0.04)), robe_dark, Vector3(0.0, 0.75, -0.22), Vector3(0.18, 0.0, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.25), robe, Vector3(0.0, 1.12, 0.0), Vector3.ZERO, Vector3(1.0, 0.95, 0.85)))
	root.add_child(MeshKit.part(MeshKit.torus(0.17, 0.24), gold, Vector3(0.0, 0.98, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.12), gold, Vector3(-0.26, 1.24, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.12), gold, Vector3(0.26, 1.24, 0.0)))

	# Head, burning hair and glowing eyes
	root.add_child(MeshKit.part(MeshKit.sphere(0.19), skin, Vector3(0.0, 1.46, 0.02)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.21), hair, Vector3(0.0, 1.5, -0.04), Vector3.ZERO, Vector3(1.05, 0.9, 1.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.028), ember, Vector3(-0.07, 1.47, 0.19)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.028), ember, Vector3(0.07, 1.47, 0.19)))

	# Wizard hat, tip leaning back
	root.add_child(MeshKit.part(MeshKit.cylinder(0.38, 0.38, 0.04, 24), robe_dark, Vector3(0.0, 1.6, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.0, 0.27, 0.62, 20), robe, Vector3(0.0, 1.92, -0.05), Vector3(-0.28, 0.0, 0.0)))
	root.add_child(MeshKit.part(MeshKit.torus(0.24, 0.29), gold, Vector3(0.0, 1.66, 0.0)))

	# Staff in the right hand with a burning orb
	var staff := Node3D.new()
	staff.position = Vector3(0.42, 0.0, 0.12)
	root.add_child(staff)
	staff.add_child(MeshKit.part(MeshKit.cylinder(0.03, 0.035, 1.75, 8), wood, Vector3(0.0, 0.88, 0.0)))
	staff.add_child(MeshKit.part(MeshKit.torus(0.1, 0.14), gold, Vector3(0.0, 1.78, 0.0), Vector3(PI * 0.5, 0.0, 0.0)))
	var orb := MeshKit.part(MeshKit.sphere(0.11), ember, Vector3(0.0, 1.8, 0.0))
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staff.add_child(orb)
	var flame := Vfx.particles({
		"amount": 18, "lifetime": 0.5, "radius": 0.06, "spread": 20.0,
		"vel_min": 0.3, "vel_max": 0.7, "gravity": Vector3(0, 1.2, 0), "size": 0.3,
		"colors": Vfx.fire_colors(),
	})
	flame.position = Vector3(0.0, 1.86, 0.0)
	staff.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(0.0, 1.8, 0.0)
	staff.add_child(light)
	root.set_meta("orb_light", light)
	return root
