class_name Unit
extends CharacterBody3D
## Base for everything that has health and belongs to a team:
## heroes, minions, monsters, towers, Cores and training dummies.

signal died(unit: Unit)
signal damaged(amount: float, source: Node)

@export var team: int = 0
@export var max_hp: float = 1000.0
@export var armor: float = 0.0
@export var move_speed: float = 5.0
@export var body_radius: float = 0.45
@export var body_height: float = 1.8
@export var bar_height: float = 2.4
@export var display_name: String = ""

var hp: float = 0.0
## Whoever dealt the most recent damage (used for kill credit).
var last_attacker: Node

var _slow_factor := 1.0
var _slow_time := 0.0
var _burn_dps := 0.0
var _burn_time := 0.0
var _burn_tick := 0.0
var _burn_source: Node
var _burn_fx: GPUParticles3D


func _ready() -> void:
	hp = max_hp
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("units")
	# Layer 1 = moving units, layer 2 = structures. Moving units only bump
	# into structures, so crowds of heroes and minions can overlap freely.
	collision_layer = 1
	collision_mask = 2
	if get_node_or_null("Body") == null:
		var shape := CapsuleShape3D.new()
		shape.radius = body_radius
		shape.height = body_height
		var collision := CollisionShape3D.new()
		collision.name = "Body"
		collision.shape = shape
		collision.position = Vector3(0.0, body_height * 0.5, 0.0)
		add_child(collision)


func _physics_process(delta: float) -> void:
	_tick_status(delta)
	_unit_physics(delta)


## Subclasses override this instead of _physics_process.
func _unit_physics(_delta: float) -> void:
	pass


func is_alive() -> bool:
	return hp > 0.0


func is_enemy_of(other: Unit) -> bool:
	return other != null and other.team != team


func hp_ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func speed_multiplier() -> float:
	return _slow_factor if _slow_time > 0.0 else 1.0


func flat_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Applies armour, shows a damage number and returns the damage actually dealt.
func take_damage(amount: float, source: Node = null, kind: String = "skill") -> float:
	if not is_alive() or amount <= 0.0 or is_protected():
		return 0.0
	var dealt := amount * 100.0 / (100.0 + maxf(armor, 0.0))
	hp = maxf(hp - dealt, 0.0)
	last_attacker = source
	damaged.emit(dealt, source)
	FloatingText.spawn(self, dealt, kind, source)
	_on_damaged(dealt, source)
	if hp <= 0.0:
		_die()
	return dealt


## True while this unit cannot be damaged (e.g. a Core whose towers still stand).
func is_protected() -> bool:
	return false


## Kills the unit outright, e.g. when its team is eliminated.
func kill() -> void:
	if is_alive():
		hp = 0.0
		_die()


func heal(amount: float) -> void:
	if is_alive():
		hp = minf(hp + amount, max_hp)


## factor is the speed multiplier while slowed (0.7 = 30% slower). Strongest slow wins.
func apply_slow(factor: float, duration: float) -> void:
	if _slow_time <= 0.0 or factor < _slow_factor:
		_slow_factor = factor
	_slow_time = maxf(_slow_time, duration)


## Deals total_damage spread over duration. A new burn refreshes the old one.
func apply_burn(total_damage: float, duration: float, source: Node = null) -> void:
	if not is_alive() or duration <= 0.0:
		return
	_burn_dps = total_damage / duration
	_burn_time = duration
	_burn_source = source
	if _burn_fx == null:
		_burn_fx = Vfx.burn_aura()
		add_child(_burn_fx)
		_burn_fx.position = Vector3(0.0, body_height * 0.55, 0.0)
	_burn_fx.emitting = true


func is_burning() -> bool:
	return _burn_time > 0.0


func _tick_status(delta: float) -> void:
	if _slow_time > 0.0:
		_slow_time -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		_burn_tick += delta
		if _burn_tick >= 0.5:
			_burn_tick -= 0.5
			take_damage(_burn_dps * 0.5, _burn_source, "burn")
		if _burn_time <= 0.0 and _burn_fx != null:
			_burn_fx.emitting = false


func _die() -> void:
	_burn_time = 0.0
	_slow_time = 0.0
	if _burn_fx != null:
		_burn_fx.emitting = false
	died.emit(self)
	_on_died()


func _on_damaged(_amount: float, _source: Node) -> void:
	pass


func _on_died() -> void:
	pass
