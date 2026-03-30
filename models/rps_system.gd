class_name RpsSystem
extends RefCounted

enum HazardProperty {
	BURNING,
	CORROSIVE,
	CURSED,
}

enum ToolProperty {
	SOAKED,
	INERT,
	CLEANSED,
	OTHER,
}

const WEAKNESS_TABLE: Dictionary = {
	ToolProperty.SOAKED: [HazardProperty.BURNING],
	ToolProperty.INERT: [HazardProperty.CORROSIVE],
	ToolProperty.CLEANSED: [HazardProperty.CURSED],
}

const BONUS_DAMAGE := 3
const BASE_DAMAGE := 1


static func is_effective(tool_property: ToolProperty, hazard_property: HazardProperty) -> bool:
	var weaknesses = WEAKNESS_TABLE.get(tool_property, [])
	return weaknesses.has(hazard_property)


static func compute_damage(tool_property: ToolProperty, hazard_property: HazardProperty) -> int:
	if is_effective(tool_property, hazard_property):
		return BONUS_DAMAGE
	return BASE_DAMAGE
