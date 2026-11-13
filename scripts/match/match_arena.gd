extends Node3D
## Phase 2 match: three teams of five on a triangle map. The player controls
## Pyrelle on team 0; the other 14 heroes are bots. Minion waves push every
## lane, towers guard the Cores, and the last team with a Core wins.

const HERO_DATA := preload("res://data/heroes/pyrelle.tres")
const LANE_SHADER := preload("res://shaders/lane_path.gdshader")
const HEROES_PER_TEAM := 5
const FIRST_WAVE_DELAY := 4.0
const WAVE_INTERVAL := 26.0

var rules: MatchRules
var player: Hero
var camera: MobaCamera
var cores: Array[Structure] = []

var _wave_timer := FIRST_WAVE_DELAY


func _ready() -> void:
	InputSetup.ensure_actions()
	_build_environment()
	_build_ground()
	_build_bases()
	_build_center()
	_build_scenery()

	rules = MatchRules.new()
	add_child(rules)
	_spawn_structures()
	_spawn_heroes()

	camera = MobaCamera.new()
	add_child(camera)
	camera.target = player
	camera.snap_to_target()
	camera.make_current()
	player.camera_rig = camera
	FloatingText.focus = player

	var aim := AimIndicator.new()
	add_child(aim)
	var hud := Hud.new()
	add_child(hud)
	hud.setup(player, camera, rules)
	var controller := PlayerController.new()
	add_child(controller)
	controller.setup(player, camera, hud, aim)


func _exit_tree() -> void:
	FloatingText.focus = null


func _physics_process(delta: float) -> void:
	if rules.winner >= 0:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_INTERVAL
		_spawn_waves()


# --- Units ---------------------------------------------------------------------

func _spawn_structures() -> void:
	for team in MapLayout.TEAM_COUNT:
		var core := Structure.new()
		core.is_core = true
		core.team = team
		core.max_hp = 9000.0
		core.armor = 80.0
		core.attack_range = 9.5
		core.attack_damage = 220.0
		core.position = MapLayout.core_position(team)
		add_child(core)
		cores.append(core)
		rules.register_structure(core)
	for lane in MapLayout.TEAM_COUNT:
		var teams := MapLayout.lane_teams(lane)
		for team in [teams.x, teams.y]:
			var tower := Structure.new()
			tower.team = team
			tower.max_hp = 4200.0
			tower.armor = 60.0
			# Beside the road on the side facing the map centre, so minions walk past it.
			var path := MapLayout.lane_path(lane, team)
			var spot := MapLayout.point_along(path, 0.3)
			var tangent := MapLayout.point_along(path, 0.32) - MapLayout.point_along(path, 0.28)
			var side := tangent.cross(Vector3.UP).normalized()
			if (spot + side).length() > spot.length():
				side = -side
			tower.position = spot + side * 3.6
			add_child(tower)
			cores[team].guard_towers.append(tower)
			rules.register_structure(tower)


func _spawn_heroes() -> void:
	var bot_number := 1
	for team in MapLayout.TEAM_COUNT:
		var lanes := MapLayout.lanes_of_team(team)
		var fountain := MapLayout.fountain_position(team)
		for slot in HEROES_PER_TEAM:
			var hero := Hero.new()
			hero.stats = HERO_DATA
			hero.team = team
			hero.arena_radius = MapLayout.PLAY_RADIUS
			var angle := TAU * float(slot) / float(HEROES_PER_TEAM)
			hero.home_position = fountain + Vector3(cos(angle), 0.0, sin(angle)) * 2.6
			hero.position = hero.home_position
			var is_player := team == 0 and slot == 0
			if not is_player:
				hero.model_tint = TeamPalette.color(team)
				hero.ring_color = Color(TeamPalette.color(team), 0.55)
			add_child(hero)
			rules.register_hero(hero)
			if is_player:
				player = hero
				hero.display_name = "คุณ"
				continue
			hero.display_name = "บอท %d" % bot_number
			bot_number += 1
			# Two heroes per lane; the fifth alternates lanes.
			var bot := HeroBot.new()
			add_child(bot)
			bot.setup(hero, lanes[slot % lanes.size()], rules)


func _spawn_waves() -> void:
	for lane in MapLayout.TEAM_COUNT:
		var teams := MapLayout.lane_teams(lane)
		for team in [teams.x, teams.y]:
			var enemy := MapLayout.enemy_on_lane(lane, team)
			if not rules.is_team_alive(team) or not rules.is_team_alive(enemy):
				continue
			var path := MapLayout.lane_path(lane, team)
			var forward := (path[1] - path[0]).normalized()
			for i in 3:
				var minion := Minion.new()
				minion.team = team
				minion.ranged = i == 2
				minion.path = path
				minion.enemy_core = cores[enemy]
				var side := Vector3(forward.z, 0.0, -forward.x) * (0.6 if i == 1 else -0.6 if i == 0 else 0.0)
				# Melee in front, the ranged minion behind them.
				minion.position = path[0] + forward * (1.4 * float(2 - i)) + side
				add_child(minion)


# --- World ---------------------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.4, 0.78)
	sky_material.sky_horizon_color = Color(0.7, 0.8, 0.95)
	sky_material.ground_bottom_color = Color(0.16, 0.2, 0.18)
	sky_material.ground_horizon_color = Color(0.58, 0.68, 0.72)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _noise_texture(frequency: float, ramp: Gradient) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture


func _build_ground() -> void:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.2, 0.42, 0.16), Color(0.32, 0.58, 0.22), Color(0.45, 0.66, 0.28)])
	var grass := StandardMaterial3D.new()
	grass.albedo_texture = _noise_texture(0.015, ramp)
	grass.uv1_scale = Vector3(14.0, 14.0, 1.0)
	grass.roughness = 0.95
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	add_child(MeshKit.part(plane, grass, Vector3.ZERO))

	var dirt_ramp := Gradient.new()
	dirt_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	dirt_ramp.colors = PackedColorArray([Color(0, 0, 0), Color(1, 1, 1)])
	var lane_material := ShaderMaterial.new()
	lane_material.shader = LANE_SHADER
	lane_material.set_shader_parameter("dirt", _noise_texture(0.03, dirt_ramp))
	for lane in MapLayout.TEAM_COUNT:
		var road := MeshInstance3D.new()
		road.mesh = _ribbon_mesh(MapLayout.lane_points(lane), MapLayout.LANE_WIDTH)
		road.material_override = lane_material
		road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(road)
	# Short roads from each fountain to its Core.
	for team in MapLayout.TEAM_COUNT:
		var spur := PackedVector3Array([MapLayout.fountain_position(team), MapLayout.core_position(team)])
		var road := MeshInstance3D.new()
		road.mesh = _ribbon_mesh(spur, MapLayout.LANE_WIDTH)
		road.material_override = lane_material
		road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(road)


## A flat strip of road along the points, slightly above the grass.
func _ribbon_mesh(points: PackedVector3Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travelled := 0.0
	for i in points.size():
		var ahead := points[mini(i + 1, points.size() - 1)]
		var behind := points[maxi(i - 1, 0)]
		var forward := (ahead - behind).normalized()
		var side := forward.cross(Vector3.UP).normalized() * width * 0.5
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		var v := travelled / width
		var lift := Vector3(0.0, 0.02, 0.0)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, v))
		st.add_vertex(points[i] + side + lift)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, v))
		st.add_vertex(points[i] - side + lift)
	for i in points.size() - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	return st.commit()


func _build_bases() -> void:
	var stone := Vfx.surface_material(Color(0.56, 0.56, 0.6), 0.9, 0.1)
	var dark := Vfx.surface_material(Color(0.32, 0.31, 0.35), 0.9, 0.1)
	for team in MapLayout.TEAM_COUNT:
		var tint := TeamPalette.color(team)
		var fountain := MapLayout.fountain_position(team)
		add_child(MeshKit.part(MeshKit.cylinder(9.0, 9.4, 0.16, 40), stone, fountain + Vector3(0.0, -0.06, 0.0)))
		var rune := Vfx.marker(Color(tint, 0.8), 0, 0.015, 0.0, 2.2)
		rune.position = fountain + Vector3(0.0, 0.05, 0.0)
		rune.scale = Vector3(8.4, 1.0, 8.4)
		add_child(rune)
		var heal_zone := Vfx.marker(Color(tint, 0.7), 0, 0.03, 0.12, 1.6)
		heal_zone.position = fountain + Vector3(0.0, 0.06, 0.0)
		heal_zone.scale = Vector3(MapLayout.FOUNTAIN_HEAL_RADIUS, 1.0, MapLayout.FOUNTAIN_HEAL_RADIUS)
		add_child(heal_zone)
		# Fountain: a basin with rising sparkles.
		add_child(MeshKit.part(MeshKit.cylinder(1.4, 1.6, 0.6, 16), dark, fountain + Vector3(0.0, 0.3, 0.0)))
		add_child(MeshKit.part(MeshKit.cylinder(1.2, 1.2, 0.05, 16), Vfx.emissive_material(tint, 1.8), fountain + Vector3(0.0, 0.62, 0.0)))
		var sparkles := Vfx.particles({
			"amount": 40, "lifetime": 1.6, "radius": 1.0, "spread": 10.0,
			"vel_min": 1.5, "vel_max": 3.0, "size": 0.25,
			"colors": Vfx.trail_colors(tint),
		})
		sparkles.position = fountain + Vector3(0.0, 0.7, 0.0)
		add_child(sparkles)
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 1.5
		light.omni_range = 8.0
		light.position = fountain + Vector3(0.0, 1.6, 0.0)
		add_child(light)
		# Banner poles around the plaza.
		for i in 6:
			var angle := TAU * float(i) / 6.0 + PI / 6.0
			var spot := fountain + Vector3(cos(angle), 0.0, sin(angle)) * 8.6
			add_child(MeshKit.part(MeshKit.cylinder(0.08, 0.1, 3.2, 6), dark, spot + Vector3(0.0, 1.6, 0.0)))
			add_child(MeshKit.part(MeshKit.box(Vector3(0.05, 1.3, 0.7)), Vfx.surface_material(tint.darkened(0.15)), spot + Vector3(0.0, 2.5, 0.38)))


## The middle of the map, where the World Boss will appear in phase 3.
func _build_center() -> void:
	var stone := Vfx.surface_material(Color(0.5, 0.48, 0.55), 0.9, 0.1)
	add_child(MeshKit.part(MeshKit.cylinder(MapLayout.BOSS_PIT_RADIUS, MapLayout.BOSS_PIT_RADIUS + 0.5, 0.2, 40), stone, Vector3(0.0, -0.08, 0.0)))
	var violet := Color(0.65, 0.4, 1.0)
	for ring_size: float in [MapLayout.BOSS_PIT_RADIUS - 0.6, 4.5]:
		var rune := Vfx.marker(Color(violet, 0.75), 0, 0.02, 0.02, 2.0)
		rune.position = Vector3(0.0, 0.05, 0.0)
		rune.scale = Vector3(ring_size, 1.0, ring_size)
		add_child(rune)
	var pillar := Vfx.surface_material(Color(0.4, 0.38, 0.45), 0.9, 0.2)
	var glow := Vfx.emissive_material(violet, 2.5)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var spot := Vector3(cos(angle), 0.0, sin(angle)) * (MapLayout.BOSS_PIT_RADIUS + 0.4)
		add_child(MeshKit.part(MeshKit.cylinder(0.45, 0.6, 2.6, 6), pillar, spot + Vector3(0.0, 1.3, 0.0)))
		add_child(MeshKit.part(MeshKit.cylinder(0.0, 0.3, 0.7, 6), glow, spot + Vector3(0.0, 2.95, 0.0)))
	var light := OmniLight3D.new()
	light.light_color = violet
	light.light_energy = 1.4
	light.omni_range = 10.0
	light.position = Vector3(0.0, 2.0, 0.0)
	add_child(light)


func _is_open_ground(point: Vector3, margin: float) -> bool:
	if point.length() < MapLayout.BOSS_PIT_RADIUS + 3.0 + margin:
		return false
	for team in MapLayout.TEAM_COUNT:
		if point.distance_to(MapLayout.fountain_position(team)) < 11.0 + margin:
			return false
		if point.distance_to(MapLayout.core_position(team)) < 6.0 + margin:
			return false
	return MapLayout.distance_to_lanes(point) > MapLayout.LANE_WIDTH * 0.5 + 1.5 + margin


## Pines around the edge, bushes and rocks in the jungle. Uses MultiMesh so
## hundreds of plants cost only a few draw calls on the iPhone.
func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pines: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var tries := 0
	while tries < 9000 and (pines.size() < 260 or bushes.size() < 140 or rocks.size() < 50):
		tries += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * 82.0
		var point := Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		if radius > MapLayout.PLAY_RADIUS + 1.0:
			if pines.size() < 260 and _is_open_ground(point, 0.0):
				pines.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(1.0, 1.7)), point))
		elif rng.randf() < 0.75:
			if bushes.size() < 140 and _is_open_ground(point, 0.5):
				bushes.append(Transform3D(spin.scaled(Vector3(1.0, 0.75, 1.0) * rng.randf_range(0.7, 1.3)), point))
		elif rocks.size() < 50 and _is_open_ground(point, 0.0):
			rocks.append(Transform3D(spin.scaled(Vector3(1.0, 0.6, 1.2) * rng.randf_range(0.5, 1.2)), point))

	var bark := Vfx.surface_material(Color(0.36, 0.23, 0.14))
	var leaf := Vfx.surface_material(Color(1, 1, 1))
	leaf.vertex_color_use_as_albedo = true
	var leaf_colors := [Color(0.16, 0.42, 0.2), Color(0.22, 0.5, 0.22), Color(0.12, 0.36, 0.24)]
	_add_multimesh(MeshKit.cylinder(0.22, 0.3, 1.4, 8), bark, pines, Vector3(0.0, 0.7, 0.0), [])
	_add_multimesh(MeshKit.cylinder(0.0, 1.5, 2.2, 10), leaf, pines, Vector3(0.0, 2.2, 0.0), leaf_colors)
	_add_multimesh(MeshKit.cylinder(0.0, 1.15, 1.8, 10), leaf, pines, Vector3(0.0, 3.2, 0.0), leaf_colors)
	var bush_colors := [Color(0.2, 0.5, 0.2), Color(0.28, 0.56, 0.24), Color(0.18, 0.44, 0.26)]
	_add_multimesh(MeshKit.sphere(0.9), leaf, bushes, Vector3(0.0, 0.45, 0.0), bush_colors)
	_add_multimesh(MeshKit.sphere(0.6), leaf, bushes, Vector3(0.6, 0.35, 0.3), bush_colors)
	_add_multimesh(MeshKit.sphere(0.8), Vfx.surface_material(Color(0.52, 0.52, 0.56), 0.95, 0.15), rocks, Vector3(0.0, 0.15, 0.0), [])


func _add_multimesh(mesh: Mesh, material: Material, spots: Array[Transform3D], offset: Vector3, colors: Array) -> void:
	if spots.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i in spots.size():
		var spot := spots[i]
		multimesh.set_instance_transform(i, spot * Transform3D(Basis(), offset))
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i % colors.size()])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
