class_name FloatingText
extends RefCounted
## Damage numbers that pop up over a unit and fade away.

const COLORS := {
	"basic": Color(1.0, 1.0, 1.0),
	"skill": Color(1.0, 0.82, 0.35),
	"burn": Color(1.0, 0.5, 0.15),
	"heal": Color(0.45, 1.0, 0.5),
}


## When set (the local hero in a match), only numbers involving it are shown,
## so dozens of minion fights don't flood the screen.
static var focus: Node = null


static func spawn(at: Node3D, amount: float, kind: String, source: Node = null) -> void:
	if not at.is_inside_tree():
		return
	if focus != null and is_instance_valid(focus) and at != focus and source != focus:
		return
	var scene := at.get_tree().current_scene
	if scene == null:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 52 if kind == "burn" else 72
	label.outline_size = 14
	label.pixel_size = 0.006
	label.modulate = COLORS.get(kind, Color.WHITE)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	scene.add_child(label)
	label.position = at.global_position + Vector3(randf_range(-0.5, 0.5), 2.6, randf_range(-0.2, 0.2))
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.3, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
