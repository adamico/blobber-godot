class_name RpsSystem
extends RefCounted

enum HazardClass {
	BURNING,
	CORROSIVE,
	CURSED,
}

enum ToolClass {
	SOAKED,
	INERT,
	CLEANSED,
	OTHER,
}

const WEAKNESS_TABLE: Dictionary = {
	ToolClass.SOAKED: [HazardClass.BURNING],
	ToolClass.INERT: [HazardClass.CORROSIVE],
	ToolClass.CLEANSED: [HazardClass.CURSED],
}

const BONUS_DAMAGE := 3
const BASE_DAMAGE := 1


static func is_effective(tool_class: ToolClass, hazard_class: HazardClass) -> bool:
	var weaknesses = WEAKNESS_TABLE.get(tool_class, [])
	return weaknesses.has(hazard_class)


static func compute_damage(tool_class: ToolClass, hazard_class: HazardClass) -> int:
	if is_effective(tool_class, hazard_class):
		return BONUS_DAMAGE
	return BASE_DAMAGE
