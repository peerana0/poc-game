class_name InputSetup
extends RefCounted
## Registers keyboard actions at runtime, so testing on a Mac works
## (WASD to move, Space to attack, Q/E/R for skills) without editing the Input Map.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"attack": [KEY_SPACE, KEY_J],
	"skill_1": [KEY_Q],
	"skill_2": [KEY_E],
	"skill_3": [KEY_R],
}


static func ensure_actions() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)
