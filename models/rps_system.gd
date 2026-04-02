class_name RpsSystem
extends RefCounted

## Integer values are explicit and stable — .tres files persist these as raw ints.
## Never renumber or reorder without a migration pass on all .tres resources.
enum HazardProperty {
	BURNING   = 0,
	CORROSIVE = 1,
	CURSED    = 2,
}

## Same stability contract as HazardProperty.
enum ToolProperty {
	SOAKED   = 0,
	INERT    = 1,
	CLEANSED = 2,
	OTHER    = 3,
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


static func effective_tool_for_hazard(hazard_property: HazardProperty) -> ToolProperty:
	for tool_property in WEAKNESS_TABLE.keys():
		var weaknesses = WEAKNESS_TABLE.get(tool_property, [])
		if weaknesses.has(hazard_property):
			return tool_property as ToolProperty
	return ToolProperty.OTHER


static func compute_damage(tool_property: ToolProperty, hazard_property: HazardProperty) -> int:
	if is_effective(tool_property, hazard_property):
		return BONUS_DAMAGE
	return BASE_DAMAGE
