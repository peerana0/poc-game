class_name PlayerController
extends Node
## Feeds the touch controls (and keyboard/mouse on a Mac) into the local hero.

var hero: Hero
var camera: MobaCamera
var hud: Hud
var aim: AimIndicator

var _touch_move := Vector2.ZERO
var _touch_attack := false
var _aiming_index := -1
var _aim_vector := Vector2.ZERO


func setup(p_hero: Hero, p_camera: MobaCamera, p_hud: Hud, p_aim: AimIndicator) -> void:
	hero = p_hero
	camera = p_camera
	hud = p_hud
	aim = p_aim
	hud.joystick.changed.connect(_on_joystick_changed)
	hud.attack_button.pressed_changed.connect(_on_attack_pressed)
	for button in hud.skill_buttons:
		button.aim_started.connect(_on_aim_started)
		button.aim_changed.connect(_on_aim_changed)
		button.aim_released.connect(_on_aim_released)


func _physics_process(_delta: float) -> void:
	if hero == null:
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	hero.move_input = _touch_move if _touch_move.length() > 0.05 else keyboard
	hero.attack_held = _touch_attack or Input.is_action_pressed("attack")
	if _aiming_index >= 0:
		_update_aim()


func _unhandled_input(event: InputEvent) -> void:
	if hero == null:
		return
	# Keyboard skills aim at the mouse cursor.
	for i in 3:
		if event.is_action_pressed("skill_%d" % (i + 1)):
			var mouse := get_viewport().get_mouse_position()
			hero.try_cast(i, camera.ground_point(mouse))


func _on_joystick_changed(value: Vector2) -> void:
	_touch_move = value


func _on_attack_pressed(down: bool) -> void:
	_touch_attack = down


func _on_aim_started(index: int) -> void:
	if index >= hero.skills.size() or not hero.skills[index].is_ready():
		return
	_aiming_index = index
	_aim_vector = Vector2.ZERO
	hud.show_cancel_zone(true)
	_update_aim()


func _on_aim_changed(index: int, vector: Vector2, finger: Vector2) -> void:
	if index != _aiming_index:
		return
	_aim_vector = vector
	hud.highlight_cancel(hud.is_over_cancel(finger))


func _on_aim_released(index: int, vector: Vector2, finger: Vector2, dragged: bool) -> void:
	if index != _aiming_index:
		return
	var cancelled := hud.is_over_cancel(finger)
	_aiming_index = -1
	aim.hide_all()
	hud.show_cancel_zone(false)
	if cancelled:
		return
	var point := hero.skill_target_point(index, vector if dragged else Vector2.ZERO)
	hero.try_cast(index, point)


func _update_aim() -> void:
	var skill := hero.skills[_aiming_index]
	aim.show_aim(hero, skill, hero.skill_target_point(_aiming_index, _aim_vector))
