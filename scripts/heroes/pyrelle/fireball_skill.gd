class_name FireballSkill
extends Skill
## Pyrelle skill 1: a fireball that explodes on the first enemy it touches,
## or at the end of its range, damaging everyone in the blast.

@export var damage: float = 220.0
@export var explosion_radius: float = 2.5
@export var projectile_speed: float = 18.0


func cast(hero: Hero, target_point: Vector3) -> void:
	var ball := Projectile.new()
	ball.owner_unit = hero
	ball.direction = hero.flat_dir_to(target_point)
	ball.speed = projectile_speed
	ball.max_distance = cast_range
	ball.hit_radius = 0.6
	hero.world().add_child(ball)
	ball.global_position = hero.cast_origin()
	Vfx.dress_projectile(ball, accent, 1.25)
	var amount := damage
	var radius := explosion_radius
	ball.on_hit = func(at: Vector3, _hit: Unit) -> void:
		var ground := Vector3(at.x, 0.0, at.z)
		for enemy in hero.enemies_in_radius(ground, radius):
			enemy.take_damage(amount, hero)
			hero.notify_skill_hit(enemy)
		PyrelleFx.explosion(hero.world(), ground, 1.0)
		hero.shake_camera(0.12, 0.18)
