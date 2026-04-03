class_name RpsSystem
extends RefCounted

## Integer values are explicit and stable — .tres files persist these as raw ints.
## Never renumber or reorder without a migration pass on all .tres resources.
enum HostileProperty {
	BURNING   = 0,
	CORROSIVE = 1,
	CURSED    = 2,
}

## Same stability contract as HostileProperty.
enum ToolProperty {
	SOAKED   = 0,
	INERT    = 1,
	CLEANSED = 2,
	OTHER    = 3,
}

const WEAKNESS_TABLE: Dictionary = {
	ToolProperty.SOAKED: [HostileProperty.BURNING],
	ToolProperty.INERT: [HostileProperty.CORROSIVE],
	ToolProperty.CLEANSED: [HostileProperty.CURSED],
}

const BONUS_DAMAGE := 3
const BASE_DAMAGE := 1


static func is_effective(tool_property: ToolProperty, hostile_property: HostileProperty) -> bool:
	var weaknesses = WEAKNESS_TABLE.get(tool_property, [])
	return weaknesses.has(hostile_property)


static func effective_tool_for_hostile(hostile_property: HostileProperty) -> ToolProperty:
	for tool_property in WEAKNESS_TABLE.keys():
		var weaknesses = WEAKNESS_TABLE.get(tool_property, [])
		if weaknesses.has(hostile_property):
			return tool_property as ToolProperty
	return ToolProperty.OTHER


static func compute_damage(tool_property: ToolProperty, hostile_property: HostileProperty) -> int:
	if is_effective(tool_property, hostile_property):
		return BONUS_DAMAGE
	return BASE_DAMAGE
