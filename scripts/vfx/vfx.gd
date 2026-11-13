class_name Vfx
extends RefCounted
## Code-built effects: particles, ground markers, flashes and materials.
## Everything is created at runtime, so no effect files need importing and
## every hero can reuse the same building blocks with its own colours.

const MARKER_SHADER := preload("res://shaders/ground_marker.gdshader")

static var _soft_texture: Texture2D
static var _additive_material: StandardMaterial3D
static var _alpha_material: StandardMaterial3D


# --- Materials -------------------------------------------------------------

## Stylised surface with a rim light, used for placeholder models.
static func surface_material(color: Color, roughness: float = 0.75, rim: float = 0.35) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.rim_enabled = true
	material.rim = rim
	material.rim_tint = 0.6
	return material


## Glowing material: emission above 1 blooms through the environment glow.
static func emissive_material(color: Color, energy: float = 3.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


static func marker_material(color: Color, shape: int = 0, ring_width: float = 0.05, fill_alpha: float = 0.12, glow: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MARKER_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("shape", shape)
	material.set_shader_parameter("ring_width", ring_width)
	material.set_shader_parameter("fill_alpha", fill_alpha)
	material.set_shader_parameter("glow", glow)
	return material


## A flat ground marker. shape 0 = circle (plane 2x2 = radius 1), 1 = rectangle.
static func marker(color: Color, shape: int = 0, ring_width: float = 0.05, fill_alpha: float = 0.12, glow: float = 1.0, size: Vector2 = Vector2(2.0, 2.0)) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = marker_material(color, shape, ring_width, fill_alpha, glow)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# --- Particles -------------------------------------------------------------

static func soft_texture() -> Texture2D:
	if _soft_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 64
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		_soft_texture = texture
	return _soft_texture


static func _particle_material(additive: bool) -> StandardMaterial3D:
	if additive and _additive_material != null:
		return _additive_material
	if not additive and _alpha_material != null:
		return _alpha_material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_texture()
	material.disable_receive_shadows = true
	if additive:
		_additive_material = material
	else:
		_alpha_material = material
	return material


static func _curve_texture(points: Array) -> CurveTexture:
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _gradient_texture(colors: Array) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	var last := maxi(colors.size() - 1, 1)
	for i in colors.size():
		offsets.append(float(i) / float(last))
		packed.append(colors[i])
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = packed
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.use_hdr = true
	return texture


## Generic particle builder. Keys (all optional): amount, lifetime, one_shot,
## explosiveness, local_coords, radius | box | ring, direction, spread,
## vel_min, vel_max, gravity, damping, scale_min, scale_max, scale_curve,
## colors, size, additive.
static func particles(opts: Dictionary) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = int(opts.get("amount", 32))
	emitter.lifetime = float(opts.get("lifetime", 1.0))
	emitter.one_shot = bool(opts.get("one_shot", false))
	emitter.explosiveness = float(opts.get("explosiveness", 0.0))
	emitter.randomness = float(opts.get("randomness", 0.4))
	emitter.local_coords = bool(opts.get("local_coords", false))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.visibility_aabb = AABB(Vector3(-25, -25, -25), Vector3(50, 50, 50))

	var process := ParticleProcessMaterial.new()
	if opts.has("box"):
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = opts["box"]
	elif opts.has("ring"):
		var ring_radius := float(opts["ring"])
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		process.emission_ring_axis = Vector3.UP
		process.emission_ring_radius = ring_radius
		process.emission_ring_inner_radius = ring_radius * 0.75
		process.emission_ring_height = 0.1
	else:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = float(opts.get("radius", 0.2))
	process.direction = opts.get("direction", Vector3.UP)
	process.spread = float(opts.get("spread", 30.0))
	process.initial_velocity_min = float(opts.get("vel_min", 1.0))
	process.initial_velocity_max = float(opts.get("vel_max", 2.0))
	process.gravity = opts.get("gravity", Vector3.ZERO)
	process.damping_min = float(opts.get("damping", 0.0))
	process.damping_max = float(opts.get("damping", 0.0))
	process.scale_min = float(opts.get("scale_min", 0.7))
	process.scale_max = float(opts.get("scale_max", 1.3))
	process.angle_min = 0.0
	process.angle_max = 360.0
	process.scale_curve = _curve_texture(opts.get("scale_curve", [Vector2(0.0, 0.35), Vector2(0.2, 1.0), Vector2(1.0, 0.0)]))
	process.color_ramp = _gradient_texture(opts.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	emitter.process_material = process

	var quad := QuadMesh.new()
	var quad_size := float(opts.get("size", 0.5))
	quad.size = Vector2(quad_size, quad_size)
	quad.material = _particle_material(bool(opts.get("additive", true)))
	emitter.draw_pass_1 = quad
	return emitter


## Adds a one-shot effect to the world and frees it when it has finished.
static func burst(world: Node, at: Vector3, effect: GPUParticles3D) -> GPUParticles3D:
	effect.one_shot = true
	world.add_child(effect)
	effect.global_position = at
	effect.emitting = true
	world.get_tree().create_timer(effect.lifetime + 0.6).timeout.connect(effect.queue_free)
	return effect


# --- Colour sets -----------------------------------------------------------

static func fire_colors() -> Array:
	return [
		Color(5.0, 3.2, 1.4, 1.0),
		Color(3.2, 1.2, 0.25, 0.95),
		Color(1.2, 0.25, 0.05, 0.6),
		Color(0.15, 0.05, 0.03, 0.0),
	]


## Hot core fading to the hero's accent colour, for trails and bolts.
static func trail_colors(color: Color) -> Array:
	return [
		Color(color.r * 4.0 + 1.0, color.g * 4.0 + 0.8, color.b * 4.0 + 0.5, 1.0),
		Color(color.r * 2.5, color.g * 2.0, color.b * 1.5, 0.9),
		Color(color.r * 0.8, color.g * 0.4, color.b * 0.3, 0.5),
		Color(color.r * 0.1, color.g * 0.05, color.b * 0.05, 0.0),
	]


# --- Presets ---------------------------------------------------------------

static func explosion(size: float = 1.0) -> GPUParticles3D:
	return particles({
		"amount": 48, "lifetime": 0.7, "one_shot": true, "explosiveness": 0.95,
		"radius": 0.3 * size, "spread": 180.0, "vel_min": 2.5 * size, "vel_max": 6.0 * size,
		"damping": 5.0, "gravity": Vector3(0, 2.0, 0), "size": 1.1 * size,
		"scale_curve": [Vector2(0.0, 0.6), Vector2(0.15, 1.0), Vector2(1.0, 0.1)],
		"colors": [Color(6, 5, 3.5, 1), Color(4, 1.6, 0.4, 1), Color(1.5, 0.35, 0.08, 0.7), Color(0.2, 0.08, 0.05, 0)],
	})


static func smoke(size: float = 1.0) -> GPUParticles3D:
	return particles({
		"amount": 20, "lifetime": 1.4, "one_shot": true, "explosiveness": 0.85,
		"radius": 0.5 * size, "spread": 180.0, "vel_min": 0.8 * size, "vel_max": 2.0 * size,
		"damping": 1.0, "gravity": Vector3(0, 1.2, 0), "size": 1.5 * size, "additive": false,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(0.4, 1.0), Vector2(1.0, 1.2)],
		"colors": [Color(0.3, 0.25, 0.2, 0.0), Color(0.25, 0.2, 0.18, 0.55), Color(0.15, 0.13, 0.12, 0.0)],
	})


static func sparks(size: float = 1.0) -> GPUParticles3D:
	return particles({
		"amount": 36, "lifetime": 0.7, "one_shot": true, "explosiveness": 1.0,
		"radius": 0.2 * size, "spread": 180.0, "vel_min": 5.0 * size, "vel_max": 11.0 * size,
		"gravity": Vector3(0, -14, 0), "size": 0.14 * size,
		"scale_curve": [Vector2(0.0, 1.0), Vector2(1.0, 0.2)],
		"colors": [Color(6, 4.5, 2, 1), Color(4, 1.8, 0.4, 1), Color(1.5, 0.4, 0.1, 0)],
	})


static func embers(radius: float = 1.0) -> GPUParticles3D:
	return particles({
		"amount": 40, "lifetime": 1.4, "radius": radius, "spread": 25.0,
		"vel_min": 0.4, "vel_max": 1.4, "gravity": Vector3(0, 0.6, 0), "size": 0.16,
		"colors": [Color(5, 2.5, 0.8, 1), Color(3, 0.9, 0.2, 0.8), Color(1, 0.2, 0.05, 0)],
	})


static func burn_aura() -> GPUParticles3D:
	return particles({
		"amount": 14, "lifetime": 0.55, "radius": 0.35, "spread": 15.0,
		"vel_min": 0.8, "vel_max": 1.6, "gravity": Vector3(0, 1.0, 0), "size": 0.45,
		"colors": fire_colors(),
	})


static func wall_flames(half_length: float) -> GPUParticles3D:
	return particles({
		"amount": 110, "lifetime": 0.9, "box": Vector3(half_length, 0.05, 0.3), "spread": 10.0,
		"vel_min": 1.6, "vel_max": 3.2, "gravity": Vector3(0, 1.2, 0), "size": 0.85,
		"scale_curve": [Vector2(0.0, 0.4), Vector2(0.3, 1.0), Vector2(1.0, 0.0)],
		"colors": fire_colors(),
	})


## Gives a projectile node a glowing core, a particle trail and a small light.
static func dress_projectile(node: Node3D, color: Color, size: float = 1.0, with_light: bool = true) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.2 * size
	sphere.height = 0.4 * size
	var core := MeshInstance3D.new()
	core.mesh = sphere
	core.material_override = emissive_material(color.lightened(0.35), 6.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(core)
	var trail := particles({
		"amount": 48, "lifetime": 0.4, "radius": 0.12 * size, "spread": 180.0,
		"vel_min": 0.1, "vel_max": 0.5, "gravity": Vector3(0, 1.2, 0),
		"size": 0.8 * size, "colors": trail_colors(color),
	})
	node.add_child(trail)
	if not with_light:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 3.5 * size
	node.add_child(light)


# --- One-off effects -------------------------------------------------------

## Expanding ring on the ground.
static func shockwave(world: Node, at: Vector3, color: Color, radius: float, duration: float = 0.45) -> void:
	var ring := marker(color, 0, 0.1, 0.0, 2.5)
	world.add_child(ring)
	ring.global_position = Vector3(at.x, 0.06, at.z)
	ring.scale = Vector3(0.2, 1.0, 0.2)
	var material := ring.material_override as ShaderMaterial
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("alpha", value), 1.0, 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


## Short burst of light, e.g. for explosions.
static func flash(world: Node, at: Vector3, color: Color, energy: float, light_range: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	world.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(light.queue_free)
