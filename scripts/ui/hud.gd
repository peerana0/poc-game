class_name Hud
extends CanvasLayer
## On-screen controls and info for the local player, laid out for a phone
## in landscape: joystick bottom-left, attack and skills bottom-right.

## Keeps controls clear of the iPhone notch and rounded corners.
const SIDE_MARGIN := 70.0

var hero: Hero
var joystick: TouchJoystick
var attack_button: SkillButton
var skill_buttons: Array[SkillButton] = []
var health_bars: HealthBars

var _root: Control
var _cancel_zone: CancelZone
var _hero_panel: HeroPanel
var _fps_label: Label
var _fps_timer := 0.0
var _hint: Label
var _rules: MatchRules
var _minimap: Minimap
var _score: ScoreBoard
var _respawn_label: Label
var _end_panel: Control


## Without rules this is the skill test HUD (fast cooldown toggle);
## with rules it adds the minimap, score, respawn timer and end screen.
func setup(p_hero: Hero, camera: MobaCamera, rules: MatchRules = null) -> void:
	hero = p_hero
	_rules = rules
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

	joystick = TouchJoystick.new()
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

	var panel_left := SIDE_MARGIN - 20.0
	if _rules != null:
		_minimap = Minimap.new()
		_minimap.local_hero = hero
		_place(_minimap, Vector2(0.0, 0.0), Vector2(SIDE_MARGIN - 20.0, 12.0), Vector2(210.0, 210.0))
		_root.add_child(_minimap)
		panel_left = SIDE_MARGIN + 200.0

	_hero_panel = HeroPanel.new()
	_hero_panel.hero = hero
	_place(_hero_panel, Vector2(0.0, 0.0), Vector2(panel_left, 14.0), Vector2(360.0, 86.0))
	_root.add_child(_hero_panel)

	_fps_label = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_fps_label, Vector2(1.0, 0.0), Vector2(right - 220.0, 12.0), Vector2(220.0, 30.0))
	_root.add_child(_fps_label)

	_hint = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_hint, Vector2(0.5, 0.0), Vector2(-280.0, 108.0), Vector2(560.0, 32.0))
	_root.add_child(_hint)

	if _rules == null:
		var cooldown_toggle := Button.new()
		cooldown_toggle.toggle_mode = true
		cooldown_toggle.button_pressed = true
		cooldown_toggle.focus_mode = Control.FOCUS_NONE
		cooldown_toggle.add_theme_font_size_override("font_size", 18)
		_place(cooldown_toggle, Vector2(1.0, 0.0), Vector2(right - 250.0, 46.0), Vector2(250.0, 46.0))
		_root.add_child(cooldown_toggle)
		cooldown_toggle.toggled.connect(func(on: bool) -> void: _set_fast_cooldowns(cooldown_toggle, on))
		_set_fast_cooldowns(cooldown_toggle, true)
		_hint.text = "ลองสกิลกับหุ่นซ้อม: แตะเพื่อยิงอัตโนมัติ ลากเพื่อเล็ง"
	else:
		_score = ScoreBoard.new()
		_score.rules = _rules
		_place(_score, Vector2(0.5, 0.0), Vector2(-170.0, 10.0), Vector2(340.0, 44.0))
		_root.add_child(_score)
		_respawn_label = _make_label(34, HORIZONTAL_ALIGNMENT_CENTER)
		_place(_respawn_label, Vector2(0.5, 0.5), Vector2(-300.0, -120.0), Vector2(600.0, 50.0))
		_root.add_child(_respawn_label)
		_hint.text = "ป้องกัน Core ของคุณ และทำลาย Core ของอีก 2 ทีม"
		_rules.team_eliminated.connect(_on_team_eliminated)
		_rules.match_over.connect(_on_match_over)

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
	if _respawn_label != null:
		if hero.is_alive():
			_respawn_label.text = ""
		elif hero.can_respawn and hero.respawn_left > 0.0:
			_respawn_label.text = "เกิดใหม่ใน %d วินาที" % ceili(hero.respawn_left)
		else:
			_respawn_label.text = ""
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


func _on_team_eliminated(team: int) -> void:
	if team == hero.team:
		_show_end("แพ้", "Core ของคุณถูกทำลาย", Color(1.0, 0.4, 0.35))
	else:
		_flash_hint("%s ถูกกำจัดแล้ว" % TeamPalette.team_name(team))


func _on_match_over(winner: int) -> void:
	if winner == hero.team:
		_show_end("ชนะ!", "ทีมของคุณเป็นทีมสุดท้ายที่เหลืออยู่", Color(1.0, 0.85, 0.3))


func _flash_hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	var tween := _hint.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _show_end(title: String, subtitle: String, color: Color) -> void:
	if _end_panel != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_end_panel = dim
	_end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_end_panel)
	var title_label := _make_label(96, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	_place(title_label, Vector2(0.5, 0.5), Vector2(-400.0, -170.0), Vector2(800.0, 120.0))
	_end_panel.add_child(title_label)
	var sub_label := _make_label(26, HORIZONTAL_ALIGNMENT_CENTER)
	sub_label.text = subtitle
	_place(sub_label, Vector2(0.5, 0.5), Vector2(-400.0, -40.0), Vector2(800.0, 40.0))
	_end_panel.add_child(sub_label)
	var again := Button.new()
	again.text = "เล่นอีกครั้ง"
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 28)
	_place(again, Vector2(0.5, 0.5), Vector2(-130.0, 40.0), Vector2(260.0, 70.0))
	_end_panel.add_child(again)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())


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


## Kill score of the three teams and the match clock.
class ScoreBoard extends Control:
	var rules: MatchRules

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if rules == null:
			return
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.08, 0.6))
		var slot := size.x / 4.0
		for team in 3:
			var tint := TeamPalette.color(team)
			if not rules.is_team_alive(team):
				tint = tint.darkened(0.6)
			var x := slot * float(team)
			draw_rect(Rect2(Vector2(x + 8.0, 10.0), Vector2(8.0, size.y - 20.0)), tint)
			draw_string(font, Vector2(x + 20.0, size.y * 0.5 + 10.0), str(rules.kills[team]), HORIZONTAL_ALIGNMENT_LEFT, slot - 24.0, 28, tint.lightened(0.3))
		var seconds := int(rules.elapsed)
		draw_string(font, Vector2(slot * 3.0, size.y * 0.5 + 8.0), "%d:%02d" % [seconds / 60, seconds % 60], HORIZONTAL_ALIGNMENT_CENTER, slot, 22)


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
