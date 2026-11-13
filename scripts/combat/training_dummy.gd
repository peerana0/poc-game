class_name TrainingDummy
extends Unit
## Practice target: wobbles when hit, heals after a pause,
## falls over at 0 HP and stands back up.

const REGEN_DELAY := 3.0
const RESPAWN_TIME := 2.5

var _model: Node3D
var _wobble := 0.0
var _time := 0.0
var _since_hit := 99.0
var _down_timer := 0.0


func _ready() -> void:
	if display_name == "":
		display_name = "หุ่นซ้อม"
	bar_height = 2.4
	super._ready()
	# Solid like a structure, so the hero bumps into it.
	collision_layer = 2
	_model = _build_model()
	add_child(_model)


func _process(delta: float) -> void:
	_time += delta
	_since_hit += delta
	_wobble = move_toward(_wobble, 0.0, delta * 2.5)
	if is_alive():
		_model.rotation.z = sin(_time * 22.0) * 0.22 * _wobble
		if _since_hit > REGEN_DELAY and hp < max_hp:
			hp = minf(hp + max_hp * 0.5 * delta, max_hp)
	else:
		_down_timer -= delta
		if _down_timer <= 0.0:
			_stand_up()


func _on_damaged(_amount: float, _source: Node) -> void:
	_wobble = 1.0
	_since_hit = 0.0


func _on_died() -> void:
	_down_timer = RESPAWN_TIME
	_model.rotation.z = 0.0
	var body := get_node("Body") as CollisionShape3D
	body.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", -PI * 0.5, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _stand_up() -> void:
	hp = max_hp
	var body := get_node("Body") as CollisionShape3D
	body.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_property(_model, "rotation:x", 0.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _build_model() -> Node3D:
	var root := Node3D.new()
	var wood := Vfx.surface_material(Color(0.42, 0.27, 0.16))
	var straw := Vfx.surface_material(Color(0.86, 0.72, 0.38))
	var cloth := Vfx.surface_material(Color(0.8, 0.2, 0.18))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.35, 0.42, 0.12), wood, Vector3(0.0, 0.06, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.07, 0.07, 1.0, 8), wood, Vector3(0.0, 0.55, 0.0)))
	root.add_child(MeshKit.part(MeshKit.cylinder(0.3, 0.25, 0.8), straw, Vector3(0.0, 1.3, 0.0)))
	root.add_child(MeshKit.part(MeshKit.sphere(0.24), straw, Vector3(0.0, 1.92, 0.0)))
	root.add_child(MeshKit.part(MeshKit.box(Vector3(1.2, 0.12, 0.12)), wood, Vector3(0.0, 1.5, 0.0)))
	root.add_child(MeshKit.part(MeshKit.torus(0.09, 0.17), cloth, Vector3(0.0, 1.3, 0.29), Vector3(PI * 0.5, 0.0, 0.0)))
	return root
