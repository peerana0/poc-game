class_name Hud
extends CanvasLayer
## On-screen controls and info for the local player, laid out for a phone
## in landscape: joystick bottom-left, attack and skills bottom-right.

## Keeps controls clear of the iPhone notch and rounded corners.
const SIDE_MARGIN := 70.0

var hero: Hero
var joystick: VirtualJoystick
var attack_button: SkillButton
var skill_buttons: Array[SkillButton] = []
var health_bars: HealthBars

var _root: Control
var _cancel_zone: CancelZone
var _hero_panel: HeroPanel
var _fps_label: Label
var _fps_timer := 0.0
var _hint: Label


func setup(p_hero: Hero, camera: MobaCamera) -> void:
	hero = p_hero
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	health_bars = HealthBars.new()
	health_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	health_bars.camera = camera
	health_bars.local_team = hero.team
	health_bars.local_hero = hero
	_root.add_child(health_bars)

	joystick = VirtualJoystick.new()
	_place(joystick, Vector2(0.0, 1.0), Vector2(SIDE_MARGIN - 30.0, -470.0), Vector2(540.0, 450.0))
	_root.add_child(joystick)

	var accent := hero.stats.accent if hero.stats != null else Color.WHITE
	var right := -(SIDE_MARGIN - 30.0)
	attack_button = _make_button(-1, "โจมตี", 86.0, accent, Vector2(right - 190.0, -170.0))
	var skill_centers := [Vector2(right - 390.0, -108.0), Vector2(right - 372.0, -280.0), Vector2(right - 208.0, -380.0)]
	for i in hero.skills.size():
		if i >= skill_centers.size():
			break
		var skill := hero.skills[i]
		var label := skill.short_label if skill.short_label != "" else skill.display_name
		var button_radius := 62.0 if skill.is_ultimate else 56.0
		skill_buttons.append(_make_button(i, label, button_radius, skill.accent, skill_centers[i]))

	_cancel_zone = CancelZone.new()
	_place(_cancel_zone, Vector2(1.0, 0.0), Vector2(right - 330.0, 110.0), Vector2(116.0, 116.0))
	_cancel_zone.visible = false
	_root.add_child(_cancel_zone)

	_hero_panel = HeroPanel.new()
	_hero_panel.hero = hero
	_place(_hero_panel, Vector2(0.0, 0.0), Vector2(SIDE_MARGIN - 20.0, 14.0), Vector2(360.0, 86.0))
	_root.add_child(_hero_panel)

	_fps_label = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_fps_label, Vector2(1.0, 0.0), Vector2(right - 220.0, 12.0), Vector2(220.0, 30.0))
	_root.add_child(_fps_label)

	var cooldown_toggle := Button.new()
	cooldown_toggle.toggle_mode = true
	cooldown_toggle.button_pressed = true
	cooldown_toggle.focus_mode = Control.FOCUS_NONE
	cooldown_toggle.add_theme_font_size_override("font_size", 18)
	_place(cooldown_toggle, Vector2(1.0, 0.0), Vector2(right - 250.0, 46.0), Vector2(250.0, 46.0))
	_root.add_child(cooldown_toggle)
	cooldown_toggle.toggled.connect(func(on: bool) -> void: _set_fast_cooldowns(cooldown_toggle, on))
	_set_fast_cooldowns(cooldown_toggle, true)

	_hint = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.text = "ลองสกิลกับหุ่นซ้อม: แตะเพื่อยิงอัตโนมัติ ลากเพื่อเล็ง"
	_place(_hint, Vector2(0.5, 0.0), Vector2(-280.0, 108.0), Vector2(560.0, 32.0))
	_root.add_child(_hint)
	var tween := _hint.create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	if hero == null:
		return
	for i in skill_buttons.size():
		var skill := hero.skills[i]
		var button := skill_buttons[i]
		button.cooldown_ratio = skill.cooldown_ratio(hero.cooldown_scale)
		button.cooldown_seconds = skill.cooldown_left
		button.queue_redraw()
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func show_cancel_zone(on: bool) -> void:
	_cancel_zone.visible = on
	_cancel_zone.hot = false
	_cancel_zone.queue_redraw()


func highlight_cancel(on: bool) -> void:
	if _cancel_zone.hot != on:
		_cancel_zone.hot = on
		_cancel_zone.queue_redraw()


func is_over_cancel(point: Vector2) -> bool:
	if not _cancel_zone.visible:
		return false
	var rect := _cancel_zone.get_global_rect()
	return rect.get_center().distance_to(point) <= rect.size.x * 0.5


func _set_fast_cooldowns(button: Button, on: bool) -> void:
	hero.cooldown_scale = 0.3 if on else 1.0
	button.text = "คูลดาวน์เร็ว: เปิด" if on else "คูลดาวน์เร็ว: ปิด"


func _make_button(index: int, label: String, button_radius: float, accent: Color, center: Vector2) -> SkillButton:
	var button := SkillButton.new()
	button.index = index
	button.label_text = label
	button.radius = button_radius
	button.accent = accent
	_place(button, Vector2(1.0, 1.0), center - Vector2(button_radius, button_radius), Vector2(button_radius, button_radius) * 2.0)
	_root.add_child(button)
	return button


func _make_label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return label


## Pins a control to an anchor point (0..1 of the screen) with an offset and size.
func _place(control: Control, anchor: Vector2, from_anchor: Vector2, control_size: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = from_anchor.x
	control.offset_top = from_anchor.y
	control.offset_right = from_anchor.x + control_size.x
	control.offset_bottom = from_anchor.y + control_size.y


## Drop zone for cancelling an aimed skill.
class CancelZone extends Control:
	var hot := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(0.85, 0.15, 0.15, 0.6) if hot else Color(0.08, 0.08, 0.12, 0.55))
		draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.45, 0.45, 0.9), 3.0, true)
		draw_string(get_theme_default_font(), Vector2(0.0, c.y + 8.0), "ยกเลิก", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22)


## Portrait, name and HP of the local hero.
class HeroPanel extends Control:
	var hero: Hero

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if hero == null:
			return
		var font := get_theme_default_font()
		var accent := hero.stats.accent if hero.stats != null else Color.WHITE
		var role := hero.stats.role if hero.stats != null else ""
		draw_rect(Rect2(Vector2(36.0, 16.0), Vector2(size.x - 40.0, size.y - 30.0)), Color(0.04, 0.05, 0.09, 0.6))
		var portrait := Vector2(43.0, 43.0)
		draw_circle(portrait, 40.0, Color(0.06, 0.06, 0.1, 0.95))
		draw_circle(portrait, 34.0, accent.darkened(0.25))
		draw_arc(portrait, 40.0, 0.0, TAU, 48, accent.lightened(0.3), 3.0, true)
		draw_string(font, Vector2(3.0, 55.0), hero.display_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 34)
		draw_string(font, Vector2(94.0, 40.0), "%s · %s" % [hero.display_name, role], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var bar := Rect2(Vector2(94.0, 50.0), Vector2(size.x - 110.0, 16.0))
		draw_rect(bar, Color(0, 0, 0, 0.65))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hero.hp_ratio(), bar.size.y)), Color(0.35, 0.9, 0.4))
		draw_string(font, Vector2(bar.position.x, bar.position.y + 13.0), "%d / %d" % [roundi(hero.hp), roundi(hero.max_hp)], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 13)
