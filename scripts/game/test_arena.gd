extends Node3D
## Phase 1 test scene: Pyrelle, training dummies and the mobile controls
## on a small arena. Used to judge skill effects and feel on the iPhone.

const HERO_DATA := preload("res://data/heroes/pyrelle.tres")
const ARENA_RADIUS := 24.0

var hero: Hero
var camera: MobaCamera


func _ready() -> void:
	InputSetup.ensure_actions()
	_build_environment()
	_build_ground()
	_build_decor()
	_spawn_dummies()
	_spawn_hero()

	camera = MobaCamera.new()
	add_child(camera)
	camera.target = hero
	camera.snap_to_target()
	camera.make_current()
	hero.camera_rig = camera

	var aim := AimIndicator.new()
	add_child(aim)

	var hud := Hud.new()
	add_child(hud)
	hud.setup(hero, camera)

	var controller := PlayerController.new()
	add_child(controller)
	controller.setup(hero, camera, hud, aim)


func _spawn_hero() -> void:
	hero = Hero.new()
	hero.stats = HERO_DATA
	hero.team = 0
	hero.arena_radius = ARENA_RADIUS
	hero.position = Vector3(0.0, 0.0, 5.0)
	add_child(hero)


func _spawn_dummies() -> void:
	# A tight group to test area damage, plus a few spread out for skill shots.
	var spots := [
		Vector3(-1.4, 0.0, -5.5), Vector3(1.4, 0.0, -5.5), Vector3(0.0, 0.0, -7.2),
		Vector3(-8.0, 0.0, -2.0), Vector3(8.0, 0.0, -2.0),
		Vector3(-5.0, 0.0, -12.0), Vector3(5.0, 0.0, -12.0),
	]
	for spot: Vector3 in spots:
		var dummy := TrainingDummy.new()
		dummy.team = 1
		dummy.max_hp = 2000.0
		dummy.armor = 20.0
		dummy.position = spot
		add_child(dummy)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_material.sky_horizon_color = Color(0.72, 0.82, 0.95)
	sky_material.ground_bottom_color = Color(0.18, 0.22, 0.2)
	sky_material.ground_horizon_color = Color(0.6, 0.7, 0.75)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.015
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.2, 0.42, 0.16), Color(0.32, 0.58, 0.22), Color(0.45, 0.66, 0.28)])
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = texture
	grass.uv1_scale = Vector3(6.0, 6.0, 1.0)
	grass.roughness = 0.95
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	add_child(MeshKit.part(plane, grass, Vector3.ZERO))

	# Stone platform with a glowing rune circle where the dummies stand.
	var center := Vector3(0.0, 0.0, -3.0)
	var stone := Vfx.surface_material(Color(0.55, 0.55, 0.6), 0.9, 0.1)
	add_child(MeshKit.part(MeshKit.cylinder(10.0, 10.4, 0.16, 48), stone, center + Vector3(0.0, -0.06, 0.0)))
	var rune_outer := Vfx.marker(Color(0.35, 0.85, 1.0, 0.8), 0, 0.012, 0.0, 2.2)
	rune_outer.position = center + Vector3(0.0, 0.05, 0.0)
	rune_outer.scale = Vector3(9.2, 1.0, 9.2)
	add_child(rune_outer)
	var rune_inner := Vfx.marker(Color(0.35, 0.85, 1.0, 0.6), 0, 0.02, 0.03, 2.0)
	rune_inner.position = center + Vector3(0.0, 0.05, 0.0)
	rune_inner.scale = Vector3(4.0, 1.0, 4.0)
	add_child(rune_inner)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bark := Vfx.surface_material(Color(0.36, 0.23, 0.14))
	var leaves := [
		Vfx.surface_material(Color(0.16, 0.42, 0.2)),
		Vfx.surface_material(Color(0.22, 0.5, 0.22)),
		Vfx.surface_material(Color(0.12, 0.36, 0.24)),
	]
	for i in 46:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(ARENA_RADIUS + 3.0, ARENA_RADIUS + 12.0)
		var pine := Node3D.new()
		pine.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		pine.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
		pine.rotation.y = rng.randf() * TAU
		var leaf: Material = leaves[i % leaves.size()]
		pine.add_child(MeshKit.part(MeshKit.cylinder(0.22, 0.3, 1.4, 8), bark, Vector3(0.0, 0.7, 0.0)))
		pine.add_child(MeshKit.part(MeshKit.cylinder(0.0, 1.5, 2.2, 10), leaf, Vector3(0.0, 2.2, 0.0)))
		pine.add_child(MeshKit.part(MeshKit.cylinder(0.0, 1.15, 1.8, 10), leaf, Vector3(0.0, 3.2, 0.0)))
		add_child(pine)

	var rock_material := Vfx.surface_material(Color(0.5, 0.5, 0.55), 0.95, 0.15)
	for i in 18:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(ARENA_RADIUS + 0.5, ARENA_RADIUS + 6.0)
		var size := rng.randf_range(0.6, 1.4)
		var rock := MeshKit.part(MeshKit.sphere(size), rock_material,
			Vector3(cos(angle) * distance, size * 0.2, sin(angle) * distance),
			Vector3(rng.randf(), rng.randf() * TAU, 0.0), Vector3(1.0, 0.6, 1.2))
		add_child(rock)

	# Glowing crystals at the platform's four corners.
	var crystal_material := Vfx.emissive_material(Color(0.35, 0.8, 1.0), 2.5)
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var spot := Vector3(cos(angle) * 11.5, 0.0, sin(angle) * 11.5 - 3.0)
		add_child(MeshKit.part(MeshKit.cylinder(0.0, 0.45, 2.4, 6), crystal_material, spot + Vector3(0.0, 1.2, 0.0)))
		var light := OmniLight3D.new()
		light.light_color = Color(0.35, 0.8, 1.0)
		light.light_energy = 1.5
		light.omni_range = 6.0
		light.position = spot + Vector3(0.0, 1.5, 0.0)
		add_child(light)
