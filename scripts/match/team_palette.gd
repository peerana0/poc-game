class_name TeamPalette
extends RefCounted
## Colours and names of the three teams. Team 0 is always the local player's team.

const COLORS := [Color(0.25, 0.62, 1.0), Color(1.0, 0.3, 0.25), Color(0.72, 0.4, 1.0)]
const NAMES := ["ทีมฟ้า", "ทีมแดง", "ทีมม่วง"]


static func color(team: int) -> Color:
	if team >= 0 and team < COLORS.size():
		return COLORS[team]
	return Color.WHITE


static func team_name(team: int) -> String:
	if team >= 0 and team < NAMES.size():
		return NAMES[team]
	return "?"
