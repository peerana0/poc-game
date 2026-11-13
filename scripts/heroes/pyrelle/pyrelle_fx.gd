class_name PyrelleFx
extends RefCounted
## Fire effects shared by Pyrelle's skills.


## Fireball / meteor explosion: fire burst, smoke, sparks, ground ring and a light flash.
static func explosion(world: Node, ground_point: Vector3, size: float) -> void:
	var at := ground_point + Vector3(0.0, 0.6 * size, 0.0)
	Vfx.burst(world, at, Vfx.explosion(size))
	Vfx.burst(world, at, Vfx.smoke(size))
	Vfx.burst(world, at, Vfx.sparks(size))
	Vfx.shockwave(world, ground_point, Color(1.0, 0.6, 0.2, 1.0), 2.4 * size, 0.4)
	Vfx.flash(world, at + Vector3.UP, Color(1.0, 0.5, 0.15), 5.0 * size, 7.0 * size, 0.35)
